import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/data/api_request_queue.dart';
import 'package:studentry/student/data/academic_document_service.dart';

void main() {
  const uploadId = 'ab000000-0000-4000-8000-000000000001';
  final bytes = utf8.encode('%PDF-1.7\nfixture');
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'studentry_pdf_transport_',
    );
    file = await File('${directory.path}/fixture.pdf').writeAsBytes(bytes);
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'only object transport carries bytes and app credentials never leave API',
    () async {
      var apiCalls = 0;
      var objectCalls = 0;
      final api = ApiClient.forTesting(
        MockClient((request) async {
          apiCalls++;
          expect(request.headers['Authorization'], 'Bearer app-token');
          if (request.url.path.endsWith('/upload-url')) {
            final body = jsonDecode(request.body) as Map;
            expect(body['id'], uploadId);
            expect(body['size'], bytes.length);
            expect(body['content_md5'], base64Encode(md5.convert(bytes).bytes));
            return http.Response(
              jsonEncode({
                'data': {
                  'completed': false,
                  'reference': 'academic/u/documents/$uploadId.pdf',
                  'upload_url':
                      'https://objects.example.test/private/file.pdf?signature=test',
                  'headers': {
                    'Content-Type': ['application/pdf'],
                    'Content-MD5': [body['content_md5']],
                    'If-None-Match': ['*'],
                  },
                },
              }),
              200,
            );
          }
          expect(request.url.path, endsWith('/uploads/$uploadId/complete'));
          return http.Response(
            jsonEncode({
              'data': {'reference': 'academic/u/documents/$uploadId.pdf'},
            }),
            200,
          );
        }),
      )..tokenProvider = () => 'app-token';
      final object = MockClient((request) async {
        objectCalls++;
        expect(request.url.host, 'objects.example.test');
        expect(request.method, 'PUT');
        expect(
          request.headers.keys.map((key) => key.toLowerCase()),
          isNot(contains('authorization')),
        );
        expect(request.headers['Content-Type'], 'application/pdf');
        expect(request.headers['If-None-Match'], '*');
        expect(request.bodyBytes, bytes);
        return http.Response('', 200);
      });
      expect(
        await AcademicDocumentService(
          client: api,
          objectClient: object,
        ).uploadPdf(file.path, uploadId: uploadId),
        'academic/u/documents/$uploadId.pdf',
      );
      expect(apiCalls, 2);
      expect(objectCalls, 1);
    },
  );

  test(
    'local disk and older server fall back to one multipart request',
    () async {
      for (final code in [404, 409]) {
        var calls = 0;
        final api = ApiClient.forTesting(
          MockClient((request) async {
            calls++;
            if (calls == 1) {
              return http.Response(
                '{"message":"Direct academic upload is unavailable"}',
                code,
              );
            }
            expect(
              request.headers['content-type'] ??
                  request.headers['Content-Type'],
              startsWith('multipart/form-data'),
            );
            return http.Response('{"data":{"reference":"legacy"}}', 201);
          }),
        );
        expect(
          await AcademicDocumentService(
            client: api,
          ).uploadPdf(file.path, uploadId: uploadId),
          'legacy',
        );
        expect(calls, 2);
      }
    },
  );

  test('permission failure and non-PDF never upload bytes', () async {
    var calls = 0;
    final api = ApiClient.forTesting(
      MockClient((request) async {
        calls++;
        return http.Response('{"message":"Forbidden"}', 403);
      }),
    );
    final service = AcademicDocumentService(
      client: api,
      objectClient: MockClient(
        (request) async => throw StateError('Unexpected object request'),
      ),
    );
    await expectLater(
      service.uploadPdf(file.path, uploadId: uploadId),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 1);
    await file.writeAsString('not a PDF');
    await expectLater(
      service.uploadPdf(file.path, uploadId: uploadId),
      throwsFormatException,
    );
    expect(calls, 1);
  });

  test(
    'completed upload needs no PUT and account change during PUT prevents completion',
    () async {
      var generation = 1;
      var calls = 0;
      final api = ApiClient.forTesting(
        MockClient((request) async {
          calls++;
          if (calls == 1) {
            return http.Response(
              '{"data":{"completed":true,"reference":"saved"}}',
              200,
            );
          }
          return http.Response('{"data":{"reference":"saved"}}', 200);
        }),
      )..sessionGenerationProvider = () => generation;
      expect(
        await AcademicDocumentService(
          client: api,
        ).uploadPdf(file.path, uploadId: uploadId),
        'saved',
      );
      calls = 0;
      final second = ApiClient.forTesting(
        MockClient((request) async {
          calls++;
          return http.Response(
            '{"data":{"completed":false,"upload_url":"https://objects.example.test/f.pdf","headers":{}}}',
            200,
          );
        }),
      )..sessionGenerationProvider = () => generation;
      final object = MockClient((request) async {
        generation++;
        return http.Response('', 200);
      });
      await expectLater(
        AcademicDocumentService(
          client: second,
          objectClient: object,
        ).uploadPdf(file.path, uploadId: uploadId),
        throwsA(isA<StaleSessionException>()),
      );
      expect(calls, 1);
    },
  );
}
