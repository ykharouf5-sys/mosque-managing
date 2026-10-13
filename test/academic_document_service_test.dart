import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/data/api_request_queue.dart';
import 'package:studentry/student/data/academic_document_service.dart';
import 'package:studentry/student/data/subject_models.dart';

void main() {
  final subject = Subject(
    id: 's1',
    name: 'PDF',
    code: 'PDF',
    academicYear: 'first',
    pdfReference: 'academic/u/documents/f.pdf',
    pdfUrl: 'https://old.example.test/file.pdf',
  );
  test(
    'managed document renews its URL on each open without fetching lists',
    () async {
      var calls = 0;
      final service = AcademicDocumentService(
        client: ApiClient.forTesting(
          MockClient((request) async {
            expect(
              request.url.path,
              endsWith('/academic/subjects/s1/document-url'),
            );
            calls++;
            return http.Response(
              jsonEncode({
                'data': {
                  'url':
                      'https://objects.example.test/file.pdf?signature=$calls',
                },
              }),
              200,
            );
          }),
        ),
      );
      expect((await service.subjectUrl(subject)).query, 'signature=1');
      expect((await service.subjectUrl(subject)).query, 'signature=2');
      expect(calls, 2);
    },
  );
  test(
    'deleted document and forbidden scope cannot open the cached URL',
    () async {
      for (final code in [403, 404]) {
        final service = AcademicDocumentService(
          client: ApiClient.forTesting(
            MockClient(
              (request) async => http.Response(
                jsonEncode({
                  'message': 'Unavailable',
                  'code': 'academic_document_missing',
                }),
                code,
              ),
            ),
          ),
        );
        await expectLater(
          service.subjectUrl(subject),
          throwsA(isA<ApiException>()),
        );
      }
    },
  );
  test(
    'missing endpoint on an older server retains its existing signed link',
    () async {
      final service = AcademicDocumentService(
        client: ApiClient.forTesting(
          MockClient(
            (request) async =>
                http.Response('{"message":"Route not found"}', 404),
          ),
        ),
      );
      expect((await service.subjectUrl(subject)).host, 'old.example.test');
    },
  );
  test(
    'external reference needs no API request and non-web URLs are rejected',
    () async {
      final service = AcademicDocumentService(
        client: ApiClient.forTesting(
          MockClient((request) async => throw StateError('Unexpected network')),
        ),
      );
      expect(
        (await service.subjectUrl(
          subject.copyWith(pdfReference: 'https://cdn.example.test/f.pdf'),
        )).host,
        'cdn.example.test',
      );
      await expectLater(
        service.subjectUrl(
          subject.copyWith(pdfReference: 'javascript:alert(1)'),
        ),
        throwsFormatException,
      );
    },
  );
}
