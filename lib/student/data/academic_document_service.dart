import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/data/api_request_queue.dart';
import 'package:studentry/shared/data/request_diagnostics.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'subject_models.dart';

class AcademicDocumentService {
  const AcademicDocumentService({this.client, this.objectClient});
  final ApiClient? client;
  final http.Client? objectClient;
  ApiClient get _api => client ?? ApiClient.instance;

  Future<Uri> lectureUrl(String subjectId, SubjectLecture lecture) async {
    var value = lecture.pdfReference ?? lecture.pdfUrl;
    if (value?.startsWith('academic/') == true) {
      final result = await _api.get(
        '/academic/subjects/$subjectId/lectures/${lecture.number}/document-url',
        force: true,
        maxRetries: 0,
        reason: RequestReason.manual,
      );
      value = result.data['data']['url'] as String;
    }
    final uri = Uri.tryParse(value ?? '');
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const FormatException('Invalid lecture document URL');
    }
    return uri;
  }

  Future<Uri> subjectUrl(Subject subject) async {
    var url = subject.pdfUrl;
    final reference = subject.pdfReference;
    if (reference != null && reference.startsWith('academic/')) {
      try {
        final response = await _api.get(
          '/academic/subjects/${subject.id}/document-url',
          force: true,
          maxRetries: 0,
          reason: RequestReason.manual,
        );
        url = response.data['data']['url'] as String;
      } on ApiException catch (error) {
        // Old servers do not have this endpoint. A deleted record on a new
        // server must never resurrect a cached document link.
        final details = error.details;
        if (error.statusCode != 404 ||
            details is Map && details['code'] == 'academic_document_missing') {
          rethrow;
        }
        if (url == null) rethrow;
      }
    } else if (reference != null) {
      url = reference;
    }
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const FormatException('Invalid academic PDF URL');
    }
    return uri;
  }

  Future<String> uploadPdf(String filePath, {String? uploadId}) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    if (bytes.length > 20 * 1024 * 1024) {
      throw Exception('PDF file exceeds 20MB');
    }
    if (bytes.length < 8 ||
        ascii.decode(bytes.take(5).toList(), allowInvalid: true) != '%PDF-') {
      throw const FormatException('The selected file is not a PDF');
    }
    final generation = _api.sessionGenerationProvider?.call();
    final token = _api.tokenProvider?.call();
    void checkSession() {
      if (generation != _api.sessionGenerationProvider?.call() ||
          token != _api.tokenProvider?.call()) {
        throw StaleSessionException();
      }
    }

    final id =
        uploadId ?? await _durableUploadId(sha256.convert(bytes).toString());
    ApiResult prepared;
    try {
      prepared = await _api.post(
        '/academic/documents/upload-url',
        body: {
          'id': id,
          'size': bytes.length,
          'content_md5': base64Encode(md5.convert(bytes).bytes),
        },
      );
    } on ApiException catch (error) {
      if (error.statusCode != 404 &&
          !(error.statusCode == 409 &&
              error.message == 'Direct academic upload is unavailable')) {
        rethrow;
      }
      checkSession();
      return _multipart(bytes, file.uri.pathSegments.last);
    }
    checkSession();
    final data = Map<String, dynamic>.from(prepared.data['data'] as Map);
    if (data['completed'] != true) {
      final url = Uri.parse(data['upload_url'] as String);
      if (url.scheme != 'https' || url.host.isEmpty) {
        throw const FormatException('Invalid direct upload URL');
      }
      final headers = <String, String>{};
      for (final entry in (data['headers'] as Map).entries) {
        final name = entry.key.toString();
        if (name.toLowerCase() == 'authorization') {
          throw const FormatException('Unexpected object authorization header');
        }
        headers[name] = entry.value is List
            ? (entry.value as List).join(',')
            : entry.value.toString();
      }
      final transport = objectClient ?? http.Client();
      http.Response uploaded;
      try {
        // A separate transport receives only the signed object headers. The
        // application's bearer token is never sent to the object-storage host.
        uploaded = await transport
            .put(url, headers: headers, body: bytes)
            .timeout(const Duration(seconds: 90));
      } finally {
        if (objectClient == null) transport.close();
      }
      checkSession();
      // A retried conditional PUT can report the original object already exists.
      // Completion checks its original size/type/header instead of replacing it.
      if ((uploaded.statusCode < 200 || uploaded.statusCode >= 300) &&
          uploaded.statusCode != 412) {
        throw ApiException(uploaded.statusCode, 'Direct PDF upload failed');
      }
    }
    final completed = await _api.post(
      '/academic/documents/uploads/$id/complete',
    );
    checkSession();
    return completed.data['data']['reference'] as String;
  }

  Future<String> uploadDocument(String filePath) async {
    if (!filePath.toLowerCase().endsWith('.html') &&
        !filePath.toLowerCase().endsWith('.htm')) {
      return uploadPdf(filePath);
    }
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('HTML file exceeds size limits');
    }
    return _multipart(bytes, file.uri.pathSegments.last);
  }

  Future<String> _durableUploadId(String digest) async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final db = await AppDatabase.database;
    return db.transaction((txn) async {
      AppDatabase.ensureDataGeneration(generation);
      final key = 'academic:pdf:upload:$digest';
      final existing = await txn.query(
        'metadata',
        where: 'key = ?',
        whereArgs: [key],
      );
      if (existing.isNotEmpty) return existing.single['value'] as String;
      final id = const Uuid().v4();
      await txn.insert('metadata', {'key': key, 'value': id});
      return id;
    });
  }

  Future<String> _multipart(List<int> bytes, String filename) async {
    final response = await _api.upload(
      '/academic/documents',
      bytes,
      filename,
      fieldName: 'document',
    );
    return response.data['data']['reference'].toString();
  }
}
