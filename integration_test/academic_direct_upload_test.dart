import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/data/api_request_queue.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/data/database_key_service.dart';
import 'package:studentry/student/data/academic_document_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const account = 'academic_pdf_upload_native_test';
  late File file;
  Future<void> clean() async {
    await AppDatabase.close();
    final root = await getDatabasesPath();
    for (final id in [account, '${account}_other']) {
      await deleteDatabase(p.join(root, 'aqua_account_$id.db'));
      await DatabaseKeyService.deleteForAccount(id);
    }
  }

  setUp(() async {
    await clean();
    await AppDatabase.activateAccount(
      accountId: account,
      clinicalScopeVersion: 1,
    );
    file = await File(
      p.join(Directory.systemTemp.path, 'academic_pdf_native_fixture.pdf'),
    ).writeAsString('%PDF-1.7\nfixture');
  });
  tearDown(() async {
    await clean();
    if (await file.exists()) await file.delete();
  });

  testWidgets(
    'lost completion response reuses upload id after restart without uploading bytes twice',
    (tester) async {
      final ids = <String>[];
      var apiCalls = 0;
      var putCalls = 0;
      final api = ApiClient.forTesting(
        MockClient((request) async {
          apiCalls++;
          if (request.url.path.endsWith('/upload-url')) {
            ids.add(jsonDecode(request.body)['id'] as String);
            return http.Response(
              jsonEncode({
                'data': {
                  'completed': ids.length > 1,
                  'upload_url': 'https://objects.example.test/f.pdf',
                  'headers': {},
                  'reference': 'durable-reference',
                },
              }),
              200,
            );
          }
          return apiCalls == 2
              ? http.Response('{"message":"lost response"}', 503)
              : http.Response(
                  '{"data":{"reference":"durable-reference"}}',
                  200,
                );
        }),
      );
      final object = MockClient((request) async {
        putCalls++;
        return http.Response('', 200);
      });
      final service = AcademicDocumentService(
        client: api,
        objectClient: object,
      );
      await expectLater(
        service.uploadPdf(file.path),
        throwsA(isA<ApiException>()),
      );
      await AppDatabase.close();
      await AppDatabase.activateAccount(
        accountId: account,
        clinicalScopeVersion: 1,
      );
      expect(await service.uploadPdf(file.path), 'durable-reference');
      expect(ids.length, 2);
      expect(ids[0], ids[1]);
      expect(putCalls, 1);
    },
  );

  testWidgets(
    'upload identity for the same file is isolated by encrypted account database',
    (tester) async {
      final ids = <String>[];
      final api = ApiClient.forTesting(
        MockClient((request) async {
          if (request.url.path.endsWith('/upload-url')) {
            ids.add(jsonDecode(request.body)['id'] as String);
            return http.Response(
              '{"data":{"completed":true,"reference":"ready"}}',
              200,
            );
          }
          return http.Response('{"data":{"reference":"ready"}}', 200);
        }),
      );
      final service = AcademicDocumentService(client: api);
      await service.uploadPdf(file.path);
      await AppDatabase.activateAccount(
        accountId: '${account}_other',
        clinicalScopeVersion: 1,
      );
      await service.uploadPdf(file.path);
      expect(ids[0], isNot(ids[1]));
    },
  );
}
