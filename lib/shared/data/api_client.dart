import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'api_request_queue.dart';

class ApiResult {
  final int statusCode;
  final dynamic data;
  final Map<String, String> headers;
  const ApiResult(this.statusCode, this.data, this.headers);
}

class ApiClient {
  ApiClient._();
  static final instance = ApiClient._();
  String? Function()? tokenProvider;
  int Function()? sessionGenerationProvider;
  final http.Client _http = http.Client();
  Future<ApiResult> get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    bool authenticated = true,
    int maxRetries = 3,
  }) => _send(
    'GET',
    path,
    query: query,
    headers: headers,
    authenticated: authenticated,
    maxRetries: maxRetries,
  );
  Future<ApiResult> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
    bool authenticated = true,
    int maxRetries = 3,
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
  }) => _send('PUT', path, body: body, headers: headers);
  Future<ApiResult> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) => _send('PATCH', path, body: body, headers: headers);
  Future<ApiResult> delete(
    String path, {
    Object? body,
    Map<String, String>? headers,
    int maxRetries = 3,
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
    final capturedToken = tokenProvider?.call();
    final capturedGeneration = sessionGenerationProvider?.call();
    return ApiRequestQueue.instance.add(() async {
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
        await _http.send(req).timeout(ApiConfig.requestTimeout),
      );
      _ensureCurrentSession(capturedGeneration);
      final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          response.statusCode,
          decoded?['message']?.toString() ?? 'Upload failed',
          decoded,
        );
      }
      return ApiResult(response.statusCode, decoded, response.headers);
    });
  }

  Future<ApiResult> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    Object? body,
    bool authenticated = true,
    int maxRetries = 3,
  }) {
    // Capture credentials at call time. A queued request created by account A
    // must never pick up account B's token if the session changes while it is
    // waiting for a concurrency slot.
    final capturedToken = tokenProvider?.call();
    final capturedGeneration = authenticated
        ? sessionGenerationProvider?.call()
        : null;
    return ApiRequestQueue.instance.add(() async {
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
      final streamed = await _http.send(req).timeout(ApiConfig.requestTimeout);
      final response = await http.Response.fromStream(streamed);
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
        throw ApiException(response.statusCode, message, decoded);
      }
      return ApiResult(response.statusCode, decoded, response.headers);
    }, maxRetries: maxRetries);
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
