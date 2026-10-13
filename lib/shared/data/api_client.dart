import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'api_request_queue.dart';
import 'request_diagnostics.dart';

class ApiResult {
  final int statusCode;
  final dynamic data;
  final Map<String, String> headers;
  const ApiResult(this.statusCode, this.data, this.headers);
}

class ApiClient {
  ApiClient._() : _http = http.Client(), _now = DateTime.now;

  /// An isolated client for transport tests. Production uses [instance].
  ApiClient.forTesting(http.Client client, {DateTime Function()? now})
    : _http = client,
      _now = now ?? DateTime.now;
  static final instance = ApiClient._();
  String? Function()? tokenProvider;
  int Function()? sessionGenerationProvider;
  final http.Client _http;
  final DateTime Function() _now;
  final Map<String, Future<ApiResult>> _reads = {};
  final Map<String, ({ApiResult result, DateTime checkedAt})> _readCache = {};
  int _readEpoch = 0;

  void invalidateReads() {
    _readEpoch++;
    _readCache.clear();
    _reads.clear();
  }

  Future<ApiResult> get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    bool authenticated = true,
    int maxRetries = 3,
    Duration freshness = Duration.zero,
    bool force = false,
    bool revalidate = false,
    RequestReason reason = RequestReason.unspecified,
  }) {
    // Keys are private, memory-only, and never logged. Credentials and the
    // generation isolate accounts, including queued requests after logout.
    Map<String, String> sorted(Map<String, String>? map) => {
      for (final key in (map?.keys.toList() ?? <String>[])..sort())
        key: map![key]!,
    };
    final frozenQuery = sorted(query);
    final frozenHeaders = sorted(headers);
    final key = jsonEncode([
      ApiConfig.baseUrl,
      path,
      frozenQuery,
      frozenHeaders,
      authenticated,
      authenticated ? tokenProvider?.call() : null,
      authenticated ? sessionGenerationProvider?.call() : null,
      maxRetries,
    ]);
    final cached = _readCache[key];
    if (!force &&
        !revalidate &&
        freshness > Duration.zero &&
        cached != null &&
        _now().difference(cached.checkedAt) < freshness) {
      RequestDiagnostics.record('GET', path, RequestSource.cache, reason);
      return Future.value(cached.result);
    }
    final active = _reads[key];
    if (active != null) {
      RequestDiagnostics.record('GET', path, RequestSource.shared, reason);
      return active;
    }
    final epoch = _readEpoch;
    late final Future<ApiResult> request;
    final conditionalHeaders = {
      ...frozenHeaders,
      if (!force &&
          freshness > Duration.zero &&
          cached != null &&
          cached.result.headers['etag'] != null &&
          !(headers?.keys.any((key) => key.toLowerCase() == 'if-none-match') ??
              false))
        'If-None-Match': cached.result.headers['etag']!,
    };
    request =
        _send(
              'GET',
              path,
              query: frozenQuery,
              headers: conditionalHeaders,
              authenticated: authenticated,
              maxRetries: maxRetries,
              reason: reason,
            )
            .then((result) {
              if (result.statusCode == 304 && cached != null) {
                result = ApiResult(200, cached.result.data, {
                  ...cached.result.headers,
                  ...result.headers,
                });
              }
              if (epoch == _readEpoch &&
                  freshness > Duration.zero &&
                  result.statusCode == 200) {
                _readCache.remove(key);
                while (_readCache.length >= 64) {
                  _readCache.remove(_readCache.keys.first);
                }
                _readCache[key] = (result: result, checkedAt: _now());
              }
              return result;
            })
            .whenComplete(() {
              if (identical(_reads[key], request)) _reads.remove(key);
            });
    _reads[key] = request;
    return request;
  }

  Future<ApiResult> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
    bool authenticated = true,
    int maxRetries = 0,
  }) => _send(
    'POST',
    path,
    body: body,
    headers: headers,
    authenticated: authenticated,
    maxRetries: maxRetries,
  );
  Future<ApiResult> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
    int maxRetries = 0,
  }) =>
      _send('PUT', path, body: body, headers: headers, maxRetries: maxRetries);
  Future<ApiResult> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
    int maxRetries = 0,
  }) => _send(
    'PATCH',
    path,
    body: body,
    headers: headers,
    maxRetries: maxRetries,
  );
  Future<ApiResult> delete(
    String path, {
    Object? body,
    Map<String, String>? headers,
    int maxRetries = 0,
  }) => _send(
    'DELETE',
    path,
    body: body,
    headers: headers,
    maxRetries: maxRetries,
  );
  Future<ApiResult> upload(
    String path,
    List<int> bytes,
    String filename, {
    Map<String, String> fields = const {},
    String fieldName = 'image',
  }) {
    invalidateReads();
    final capturedToken = tokenProvider?.call();
    final capturedGeneration = sessionGenerationProvider?.call();
    return ApiRequestQueue.instance
        .add(() async {
          _ensureCurrentSession(capturedGeneration);
          final req = http.MultipartRequest(
            'POST',
            Uri.parse('${ApiConfig.baseUrl}$path'),
          );
          if (capturedToken != null) {
            req.headers['Authorization'] = 'Bearer $capturedToken';
          }
          req.headers['Accept'] = 'application/json';
          req.fields.addAll(fields);
          req.files.add(
            http.MultipartFile.fromBytes(fieldName, bytes, filename: filename),
          );
          final response = await http.Response.fromStream(
            await _http.send(req).timeout(const Duration(seconds: 90)),
          );
          _ensureCurrentSession(capturedGeneration);
          final decoded = response.body.isEmpty
              ? null
              : jsonDecode(response.body);
          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw ApiException(
              response.statusCode,
              decoded?['message']?.toString() ?? 'Upload failed',
              decoded,
              response.headers,
            );
          }
          return ApiResult(response.statusCode, decoded, response.headers);
        }, maxRetries: 0)
        .whenComplete(invalidateReads);
  }

  Future<ApiResult> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    Object? body,
    bool authenticated = true,
    int maxRetries = 3,
    RequestReason reason = RequestReason.mutation,
  }) {
    if (method != 'GET') invalidateReads();
    // Capture credentials at call time. A queued request created by account A
    // must never pick up account B's token if the session changes while it is
    // waiting for a concurrency slot.
    final capturedToken = tokenProvider?.call();
    final capturedGeneration = authenticated
        ? sessionGenerationProvider?.call()
        : null;
    return ApiRequestQueue.instance
        .add(() async {
          if (authenticated) _ensureCurrentSession(capturedGeneration);
          final base = Uri.parse('${ApiConfig.baseUrl}$path');
          final uri = base.replace(queryParameters: query);
          final req = http.Request(method, uri);
          req.headers.addAll({
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            ...?headers,
          });
          if (authenticated && capturedToken != null) {
            req.headers['Authorization'] = 'Bearer $capturedToken';
          }
          if (body != null) req.body = jsonEncode(body);
          final watch = Stopwatch()..start();
          late http.Response response;
          try {
            final streamed = await _http
                .send(req)
                .timeout(ApiConfig.requestTimeout);
            response = await http.Response.fromStream(streamed);
            RequestDiagnostics.record(
              method,
              path,
              RequestSource.network,
              reason,
              status: response.statusCode,
              bytes: response.bodyBytes.length,
              elapsedMs: watch.elapsedMilliseconds,
            );
          } catch (_) {
            RequestDiagnostics.record(
              method,
              path,
              RequestSource.network,
              reason,
              elapsedMs: watch.elapsedMilliseconds,
            );
            rethrow;
          }
          if (authenticated) _ensureCurrentSession(capturedGeneration);
          dynamic decoded;
          if (response.body.isNotEmpty) {
            try {
              decoded = jsonDecode(response.body);
            } catch (_) {
              decoded = response.body;
            }
          }
          if ((response.statusCode < 200 || response.statusCode >= 300) &&
              response.statusCode != 304) {
            final message = decoded is Map
                ? (decoded['message']?.toString() ?? 'API error')
                : 'API error ${response.statusCode}';
            throw ApiException(
              response.statusCode,
              message,
              decoded,
              response.headers,
            );
          }
          return ApiResult(response.statusCode, decoded, response.headers);
        }, maxRetries: maxRetries)
        .whenComplete(() {
          if (method != 'GET') invalidateReads();
        });
  }

  void _ensureCurrentSession(int? capturedGeneration) {
    final currentGeneration = sessionGenerationProvider?.call();
    if (capturedGeneration != null && currentGeneration != capturedGeneration) {
      throw const StaleSessionException();
    }
  }
}

class StaleSessionException implements Exception {
  const StaleSessionException();

  @override
  String toString() => 'The authenticated session changed during the request.';
}
