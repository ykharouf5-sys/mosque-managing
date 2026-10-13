import 'dart:async';
import 'dart:convert';
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
import 'package:studentry/student/data/academic_delta_sync.dart';
import 'package:studentry/student/data/academic_local_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const account = 'academic_delta_native_test';
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
  });
  tearDown(clean);

  Map<String, dynamic> row(String id, [String? name]) => {
    'id': id,
    'name': name ?? id,
    'code': id,
    'academicYear': 'first',
    'version': 1,
  };
  Map<String, dynamic> change(String id, [String? name]) => {
    'id': id,
    'deleted': false,
    'row': row(id, name),
  };
  http.Response page(
    List<Map<String, dynamic>> subjects, {
    List<Map<String, dynamic>> enrollments = const [],
    bool reset = false,
    String? next,
    String? checkpoint = 'completed',
  }) => http.Response(
    jsonEncode({
      'changes': {'subjects': subjects, 'enrollments': enrollments},
      'reset_required': reset,
      'next_cursor': next,
      'checkpoint': next == null ? checkpoint : null,
    }),
    200,
  );
  Future<void> seed() => AcademicLocalStore.applySync(
    {
      'subjects': [change('old')],
      'enrollments': [],
    },
    reset: true,
    checkpoint: 'old-checkpoint',
    generation: AppDatabase.captureActiveDataGeneration(),
  );

  testWidgets(
    'bootstrap commits all bounded pages and an unchanged sync makes one request',
    (tester) async {
      var calls = 0;
      final api = ApiClient.forTesting(
        MockClient((request) async {
          expect(request.url.path, endsWith('/academic/sync/pull'));
          expect(request.url.queryParameters['limit'], '25');
          calls++;
          if (calls == 1) {
            expect(
              request.url.queryParameters.containsKey('checkpoint'),
              false,
            );
            return page(
              List.generate(25, (i) => change('s$i')),
              reset: true,
              next: 'cursor-1',
            );
          }
          if (calls == 2) {
            expect(request.url.queryParameters['cursor'], 'cursor-1');
            return page(List.generate(3, (i) => change('s${25 + i}')));
          }
          expect(request.url.queryParameters['checkpoint'], 'completed');
          return page([]);
        }),
      );
      await AcademicDeltaSync.pull(client: api);
      expect((await AcademicLocalStore.read('subjects')).length, 28);
      await AppDatabase.close();
      await AppDatabase.activateAccount(
        accountId: account,
        clinicalScopeVersion: 1,
      );
      await AcademicDeltaSync.pull(client: api);
      expect(calls, 3);
      expect((await AcademicLocalStore.read('subjects')).length, 28);
    },
  );

  testWidgets(
    'failed continuation preserves both snapshots and checkpoint across restart',
    (tester) async {
      await seed();
      var calls = 0;
      final failing = ApiClient.forTesting(
        MockClient((request) async {
          calls++;
          if (calls == 1) {
            return page([change('new')], reset: true, next: 'next');
          }
          return http.Response('{"message":"unavailable"}', 503);
        }),
      );
      await expectLater(
        AcademicDeltaSync.pull(client: failing),
        throwsA(isA<ApiException>()),
      );
      await AppDatabase.close();
      await AppDatabase.activateAccount(
        accountId: account,
        clinicalScopeVersion: 1,
      );
      expect((await AcademicLocalStore.read('subjects')).single['id'], 'old');
      expect(
        await AcademicLocalStore.syncCheckpoint(
          AppDatabase.captureActiveDataGeneration(),
        ),
        'old-checkpoint',
      );
      await AcademicDeltaSync.pull(
        client: ApiClient.forTesting(
          MockClient((request) async {
            expect(request.url.queryParameters['checkpoint'], 'old-checkpoint');
            return page([change('new')], reset: true);
          }),
        ),
      );
      expect((await AcademicLocalStore.read('subjects')).single['id'], 'new');
    },
  );

  testWidgets(
    'delta deletes remote rows but preserves edits made while the request is in flight',
    (tester) async {
      await seed();
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final api = ApiClient.forTesting(
        MockClient((request) async {
          started.complete();
          return response.future;
        }),
      );
      final first = AcademicDeltaSync.pull(client: api);
      final shared = AcademicDeltaSync.pull(client: api);
      expect(identical(first, shared), true);
      await started.future;
      await AcademicLocalStore.enqueue(
        'subjects',
        'edited',
        'POST',
        '/academic/subjects',
        {'id': 'edited', 'name': 'Local'},
        row('edited', 'Local'),
      );
      response.complete(
        page([
          {'id': 'old', 'deleted': true, 'row': null},
          change('edited', 'Remote'),
          change('other'),
        ]),
      );
      await first;
      final rows = await AcademicLocalStore.read('subjects');
      expect(rows.any((item) => item['id'] == 'old'), false);
      expect(
        rows.singleWhere((item) => item['id'] == 'edited')['name'],
        'Local',
      );
      expect(rows.any((item) => item['id'] == 'other'), true);
    },
  );

  testWidgets('scope reset during paging discards earlier scope rows', (
    tester,
  ) async {
    await seed();
    var calls = 0;
    await AcademicDeltaSync.pull(
      client: ApiClient.forTesting(
        MockClient((request) async {
          calls++;
          return calls == 1
              ? page([change('old-university')], next: 'next')
              : page([change('new-university')], reset: true);
        }),
      ),
    );
    expect(
      (await AcademicLocalStore.read('subjects')).single['id'],
      'new-university',
    );
  });

  testWidgets(
    'account change rejects an old response before writing its checkpoint',
    (tester) async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final api = ApiClient.forTesting(
        MockClient((request) async {
          started.complete();
          return response.future;
        }),
      );
      final run = AcademicDeltaSync.pull(client: api);
      final expectation = expectLater(
        run,
        throwsA(isA<StaleAccountDataException>()),
      );
      await started.future;
      await AppDatabase.activateAccount(
        accountId: '${account}_other',
        clinicalScopeVersion: 1,
      );
      response.complete(page([change('private')], reset: true));
      await expectation;
      expect(await AcademicLocalStore.read('subjects'), isEmpty);
      expect(
        await AcademicLocalStore.syncCheckpoint(
          AppDatabase.captureActiveDataGeneration(),
        ),
        isNull,
      );
    },
  );

  testWidgets('old server falls back only on a missing first endpoint', (
    tester,
  ) async {
    await seed();
    final paths = <String>[];
    await AcademicDeltaSync.pull(
      client: ApiClient.forTesting(
        MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.endsWith('/sync/pull')) {
            return http.Response('{}', 404);
          }
          return http.Response(
            jsonEncode({
              'data': request.url.path.endsWith('/subjects')
                  ? [row('legacy')]
                  : [],
            }),
            200,
          );
        }),
      ),
    );
    expect(paths.length, 3);
    expect((await AcademicLocalStore.read('subjects')).single['id'], 'legacy');
    expect(
      await AcademicLocalStore.syncCheckpoint(
        AppDatabase.captureActiveDataGeneration(),
      ),
      isNull,
    );
  });

  testWidgets(
    'local commit failure rolls back snapshots and checkpoint together',
    (tester) async {
      await seed();
      final db = await AppDatabase.database;
      await db.execute(
        "CREATE TRIGGER reject_delta BEFORE INSERT ON metadata WHEN NEW.key = 'academic_sync_checkpoint' BEGIN SELECT RAISE(ABORT, 'forced'); END",
      );
      await expectLater(
        AcademicDeltaSync.pull(
          client: ApiClient.forTesting(
            MockClient((request) async => page([change('new')], reset: true)),
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect((await AcademicLocalStore.read('subjects')).single['id'], 'old');
      expect(
        await AcademicLocalStore.syncCheckpoint(
          AppDatabase.captureActiveDataGeneration(),
        ),
        'old-checkpoint',
      );
    },
  );
}
