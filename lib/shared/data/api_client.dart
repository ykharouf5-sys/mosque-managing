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
  Future<ApiResult> delete(String path, {Map<String, String>? headers}) =>
      _send('DELETE', path, headers: headers);
  Future<ApiResult> upload(
    String path,
    List<int> bytes,
    String filename, {
    Map<String, String> fields = const {},
  }) => ApiRequestQueue.instance.add(() async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}$path'),
    );
    final token = tokenProvider?.call();
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.headers['Accept'] = 'application/json';
    req.fields.addAll(fields);
    req.files.add(
      http.MultipartFile.fromBytes('image', bytes, filename: filename),
    );
    final response = await http.Response.fromStream(
      await _http.send(req).timeout(ApiConfig.requestTimeout),
    );
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
  Future<ApiResult> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    Object? body,
    bool authenticated = true,
    int maxRetries = 3,
  }) => ApiRequestQueue.instance.add(() async {
    final base = Uri.parse('${ApiConfig.baseUrl}$path');
    final uri = base.replace(queryParameters: query);
    final req = http.Request(method, uri);
    req.headers.addAll({
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      ...?headers,
    });
    final token = tokenProvider?.call();
    if (authenticated && token != null) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    if (body != null) req.body = jsonEncode(body);
    final streamed = await _http.send(req).timeout(ApiConfig.requestTimeout);
    final response = await http.Response.fromStream(streamed);
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
