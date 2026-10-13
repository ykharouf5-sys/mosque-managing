import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/data/database_key_service.dart';
import 'package:studentry/shared/data/encryption_service.dart';
import 'package:studentry/shared/data/local_database.dart';
import 'package:studentry/student/data/academic_local_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const account = 'outbox_compaction_native_test';
  Future<void> clean() async {
    await AppDatabase.close();
    final root = await getDatabasesPath();
    await deleteDatabase(p.join(root, 'aqua_account_$account.db'));
    await DatabaseKeyService.deleteForAccount(account);
  }

  setUp(() async {
    await clean();
    await AppDatabase.activateAccount(
      accountId: account,
      clinicalScopeVersion: 1,
    );
  });
  tearDown(clean);

  Future<Map<String, dynamic>> body(Map<String, Object?> row) async =>
      Map<String, dynamic>.from(
        jsonDecode(await EncryptionService.decrypt(row['payload'] as String))
            as Map,
      );
  Future<void> deliveredPatient(String id) async {
    await AppDatabase.insertPatient({'id': id, 'name': 'Initial'});
    final head = (await LocalDatabaseService.getPendingQueue(
      claim: true,
    )).single;
    final row = Map<String, dynamic>.from(
      (await (await AppDatabase.database).query('patients')).single,
    );
    await LocalDatabaseService.completeClinicalOperation(head, {
      ...row,
      'version': 7,
    }, expectedGeneration: AppDatabase.captureActiveDataGeneration());
  }

  Map<String, dynamic> appointment(String id, String patientId) => {
    'id': id,
    'patientId': patientId,
    'patientName': 'Initial',
    'date': '2026-10-06',
    'time': '09:00',
    'status': 'pending',
  };
  Future<void> subject(String id, String method, String name, int version) =>
      AcademicLocalStore.enqueue(
        'subjects',
        id,
        method,
        method == 'POST' ? '/academic/subjects' : '/academic/subjects/$id',
        {
          if (method == 'POST') 'id': id,
          'name': name,
          if (method == 'PUT') 'version': version,
        },
        {'id': id, 'name': name, 'version': method == 'POST' ? 1 : version + 1},
      );

  testWidgets(
    'create and repeated partial edits become one encrypted final create',
    (tester) async {
      await AppDatabase.insertPatient({
        'id': 'p1',
        'name': 'Initial',
        'phone': '11',
      });
      await AppDatabase.updatePatient('p1', {'phone': '22'});
      await AppDatabase.updatePatient('p1', {'name': 'Final'});
      final db = await AppDatabase.database;
      final queue = await db.query('sync_queue');
      expect(queue.length, 1);
      expect(queue.single['operation'], 'insert');
      expect(queue.single['attempted'], 0);
      expect(queue.single['payload'], isNot(contains('Final')));
      expect(await body(queue.single), containsPair('name', 'Final'));
      expect(await body(queue.single), containsPair('phone', '22'));
      await AppDatabase.close();
      await AppDatabase.activateAccount(
        accountId: account,
        clinicalScopeVersion: 1,
      );
      expect(
        (await LocalDatabaseService.getPendingQueue()).single.operation,
        'insert',
      );
      expect(
        (await (await AppDatabase.database).query('patients')).single['name'],
        'Final',
      );
    },
  );

  testWidgets(
    'updates merge across independent patients while preserving version and fields',
    (tester) async {
      await deliveredPatient('p1');
      await AppDatabase.updatePatient('p1', {'phone': '22'});
      await AppDatabase.insertPatient({'id': 'p2', 'name': 'Independent'});
      await AppDatabase.updatePatient('p1', {'name': 'Final'});
      final queue = await (await AppDatabase.database).query(
        'sync_queue',
        where: 'record_id = ?',
        whereArgs: ['p1'],
      );
      expect(queue.length, 1);
      final value = await body(queue.single);
      expect(value['version'], 7);
      expect(value['phone'], '22');
      expect(value['name'], 'Final');
      await AppDatabase.softDeletePatient('p1');
      final deleted = await (await AppDatabase.database).query(
        'sync_queue',
        where: 'record_id = ?',
        whereArgs: ['p1'],
      );
      expect(deleted.single['operation'], 'delete');
      expect((await body(deleted.single))['version'], 7);
    },
  );

  testWidgets(
    'unsent create delete cancels patients and appointments without network',
    (tester) async {
      await AppDatabase.insertPatient({'id': 'cancel', 'name': 'Cancelled'});
      await AppDatabase.softDeletePatient('cancel');
      var db = await AppDatabase.database;
      expect(await db.query('sync_queue'), isEmpty);
      expect((await db.query('patients')).single['deleted_at'], isNotNull);
      expect((await db.query('patients')).single['is_synced'], 1);
      await AppDatabase.insertAppointment(appointment('a1', 'existing'));
      await AppDatabase.softDeleteAppointment('a1');
      expect(await db.query('sync_queue'), isEmpty);
    },
  );

  testWidgets(
    'dependent appointment remains between patient create and delete',
    (tester) async {
      await AppDatabase.insertPatient({'id': 'p1', 'name': 'Parent'});
      await AppDatabase.insertAppointment(appointment('a1', 'p1'));
      await AppDatabase.softDeletePatient('p1');
      final db = await AppDatabase.database;
      expect((await db.query('sync_queue')).length, 3);
      var ready = await LocalDatabaseService.getPendingQueue(claim: true);
      expect(ready.single.tableName, 'patients');
      await LocalDatabaseService.completeClinicalOperation(
        ready.single,
        {'version': 1},
        expectedGeneration: AppDatabase.captureActiveDataGeneration(),
      );
      ready = await LocalDatabaseService.getPendingQueue();
      expect(ready.map((row) => row.tableName), ['appointments', 'patients']);
      expect(ready.last.operation, 'delete');
    },
  );

  testWidgets(
    'claim and retry keep the exact key and payload through restart',
    (tester) async {
      await AppDatabase.insertPatient({'id': 'p1', 'name': 'Sent'});
      final sent = (await LocalDatabaseService.getPendingQueue(
        claim: true,
      )).single;
      await AppDatabase.updatePatient('p1', {'name': 'Later'});
      await AppDatabase.updatePatient('p1', {'phone': '33'});
      await LocalDatabaseService.scheduleRetry(
        sent.id,
        delay: const Duration(hours: 1),
      );
      await AppDatabase.close();
      await AppDatabase.activateAccount(
        accountId: account,
        clinicalScopeVersion: 1,
      );
      final queue = await (await AppDatabase.database).query(
        'sync_queue',
        orderBy: 'id',
      );
      expect(queue.length, 2);
      expect(queue.first['operation_id'], sent.operationId);
      expect((await body(queue.first))['name'], 'Sent');
      expect((await body(queue.last))['name'], 'Later');
      expect((await body(queue.last))['phone'], '33');
      expect(await LocalDatabaseService.getPendingQueue(), isEmpty);
    },
  );

  testWidgets(
    'compaction failure rolls back the visible write and original operation',
    (tester) async {
      await AppDatabase.insertPatient({'id': 'p1', 'name': 'Original'});
      final db = await AppDatabase.database;
      final before = (await db.query('sync_queue')).single;
      await db.execute(
        "CREATE TRIGGER fail_compaction BEFORE UPDATE ON sync_queue BEGIN SELECT RAISE(ABORT, 'test'); END",
      );
      await expectLater(
        AppDatabase.updatePatient('p1', {'name': 'Lost'}),
        throwsA(isA<DatabaseException>()),
      );
      expect((await db.query('patients')).single['name'], 'Original');
      expect((await db.query('sync_queue')).single, before);
    },
  );

  testWidgets(
    'appointments preserve later edits when create acknowledgement arrives',
    (tester) async {
      await AppDatabase.insertAppointment(appointment('a1', 'p1'));
      await AppDatabase.updateAppointment('a1', {'treatment': 'One'});
      var head = (await LocalDatabaseService.getPendingQueue(
        claim: true,
      )).single;
      expect(head.operation, 'insert');
      await AppDatabase.updateAppointment('a1', {'treatment': 'Two'});
      await AppDatabase.updateAppointment('a1', {'status': 'completed'});
      await LocalDatabaseService.completeClinicalOperation(head, {
        'version': 1,
        'treatment': 'One',
      }, expectedGeneration: AppDatabase.captureActiveDataGeneration());
      final row = (await (await AppDatabase.database).query(
        'appointments',
      )).single;
      expect(row['treatment'], 'Two');
      expect(row['status'], 'completed');
      head = (await LocalDatabaseService.getPendingQueue()).single;
      expect(jsonDecode(head.payload)['version'], 1);
    },
  );

  testWidgets(
    'academic create edits send one request with correct version and canonical ack',
    (tester) async {
      await subject('s1', 'POST', 'Initial', 1);
      await subject('s1', 'PUT', 'Two', 1);
      await subject('s1', 'PUT', 'Final', 1);
      final queued = await (await AppDatabase.database).query(
        'academic_outbox',
      );
      expect(queued.length, 1);
      expect(queued.single['method'], 'POST');
      expect(jsonDecode(queued.single['body'] as String)['version'], isNull);
      expect((await AcademicLocalStore.read('subjects')).single['version'], 1);
      final requests = <http.Request>[];
      final client = ApiClient.forTesting(
        MockClient((request) async {
          requests.add(request);
          expect(jsonDecode(request.body)['name'], 'Final');
          return http.Response(
            jsonEncode({
              'data': {'id': 's1', 'name': 'Canonical', 'version': 1},
            }),
            201,
          );
        }),
      );
      await AcademicLocalStore.flush(client: client);
      expect(requests.length, 1);
      expect(
        await (await AppDatabase.database).query('academic_outbox'),
        isEmpty,
      );
      expect(
        (await AcademicLocalStore.read('subjects')).single['name'],
        'Canonical',
      );
    },
  );

  testWidgets(
    'academic in-flight edits coalesce separately and keep optimistic data',
    (tester) async {
      await subject('s1', 'POST', 'Sent', 1);
      final started = Completer<void>();
      final release = Completer<void>();
      final requests = <http.Request>[];
      final client = ApiClient.forTesting(
        MockClient((request) async {
          requests.add(request);
          if (requests.length == 1) {
            started.complete();
            await release.future;
          }
          final requestBody = jsonDecode(request.body) as Map;
          final version = request.method == 'POST'
              ? 1
              : (requestBody['version'] as int) + 1;
          return http.Response(
            jsonEncode({
              'data': {
                'id': 's1',
                'name': requestBody['name'],
                'version': version,
              },
            }),
            200,
          );
        }),
      );
      final run = AcademicLocalStore.flush(client: client);
      await started.future;
      expect(identical(AcademicLocalStore.flush(client: client), run), isTrue);
      final first = (await (await AppDatabase.database).query(
        'academic_outbox',
      )).single;
      await subject('s1', 'PUT', 'Intermediate', 1);
      await subject('s1', 'PUT', 'Latest', 2);
      final queue = await (await AppDatabase.database).query(
        'academic_outbox',
        orderBy: 'sequence',
      );
      expect(queue.length, 2);
      expect(queue.first['body'], first['body']);
      expect(queue.first['operation_id'], first['operation_id']);
      release.complete();
      await run;
      expect(
        (await AcademicLocalStore.read('subjects')).single['name'],
        'Latest',
      );
      expect((await AcademicLocalStore.read('subjects')).single['version'], 2);
      await AcademicLocalStore.flush(client: client);
      expect(requests.length, 2);
      expect(jsonDecode(requests.last.body)['version'], 1);
      expect(
        (await AcademicLocalStore.read('subjects')).single['name'],
        'Latest',
      );
    },
  );

  testWidgets(
    'academic create delete cancels but dependent enrollment prevents cancellation',
    (tester) async {
      await subject('unused', 'POST', 'Unused', 1);
      await AcademicLocalStore.enqueue(
        'subjects',
        'unused',
        'DELETE',
        '/academic/subjects/unused',
        {},
        null,
      );
      expect(
        await (await AppDatabase.database).query('academic_outbox'),
        isEmpty,
      );
      await subject('parent', 'POST', 'Parent', 1);
      await AcademicLocalStore.enqueue(
        'enrollments',
        'e1',
        'POST',
        '/academic/enrollments',
        {'id': 'e1', 'subject_id': 'parent'},
        {'enrollmentId': 'e1', 'subjectId': 'parent', 'version': 1},
      );
      await AcademicLocalStore.enqueue(
        'subjects',
        'parent',
        'DELETE',
        '/academic/subjects/parent',
        {},
        null,
      );
      final queue = await (await AppDatabase.database).query(
        'academic_outbox',
        orderBy: 'sequence',
      );
      expect(queue.map((row) => row['method']), ['POST', 'POST', 'DELETE']);
    },
  );

  testWidgets(
    'permanent academic error blocks dependent writes and remains after restart',
    (tester) async {
      await subject('parent', 'POST', 'Parent', 1);
      await AcademicLocalStore.enqueue(
        'enrollments',
        'e1',
        'POST',
        '/academic/enrollments',
        {'id': 'e1', 'subject_id': 'parent'},
        {'enrollmentId': 'e1', 'subjectId': 'parent'},
      );
      var count = 0;
      final client = ApiClient.forTesting(
        MockClient((request) async {
          count++;
          return http.Response('{"message":"conflict"}', 409);
        }),
      );
      await expectLater(
        AcademicLocalStore.flush(client: client),
        throwsStateError,
      );
      expect(count, 1);
      await AppDatabase.close();
      await AppDatabase.activateAccount(
        accountId: account,
        clinicalScopeVersion: 1,
      );
      await expectLater(
        AcademicLocalStore.flush(client: client),
        throwsStateError,
      );
      expect(count, 1);
      expect(
        (await (await AppDatabase.database).query('academic_outbox')).length,
        2,
      );
    },
  );

  testWidgets(
    'appointment pull cannot overwrite a pending edit or resurrect a pending deletion',
    (tester) async {
      await AppDatabase.insertAppointment(appointment('protected', 'p'));
      final db = await AppDatabase.database;
      await db.delete('sync_queue');
      final delivered = Map<String, dynamic>.from(
        (await db.query('appointments')).single,
      );
      await AppDatabase.upsertAppointmentFromSync({...delivered, 'version': 7});
      await AppDatabase.updateAppointment('protected', {'time': '10:00'});
      final newerRemote = {
        ...delivered,
        'time': '11:00',
        'version': 8,
        'updated_at': '2099-01-01T00:00:00Z',
      };
      await AppDatabase.upsertAppointmentFromSync(newerRemote);
      expect(
        (await AppDatabase.getAppointmentById('protected'))!['time'],
        '10:00',
      );
      expect(
        (await AppDatabase.getAppointmentById('protected'))!['version'],
        7,
      );
      await AppDatabase.softDeleteAppointment('protected');
      await AppDatabase.upsertAppointmentFromSync(newerRemote);
      expect(await AppDatabase.getAppointmentById('protected'), isNull);
      expect((await db.query('sync_queue')).single['operation'], 'delete');
    },
  );

  testWidgets(
    '100 offline edits have one final operation and one academic HTTP request',
    (tester) async {
      final watch = Stopwatch()..start();
      await AppDatabase.insertPatient({'id': 'p1', 'name': 'Initial'});
      await subject('s1', 'POST', 'Initial', 1);
      for (var i = 1; i <= 100; i++) {
        await AppDatabase.updatePatient('p1', {'name': 'Edit $i'});
        await subject('s1', 'PUT', 'Edit $i', 1);
      }
      watch.stop();
      final db = await AppDatabase.database;
      expect((await db.query('sync_queue')).length, 1);
      expect((await db.query('academic_outbox')).length, 1);
      var count = 0;
      await AcademicLocalStore.flush(
        client: ApiClient.forTesting(
          MockClient((request) async {
            count++;
            expect(jsonDecode(request.body)['name'], 'Edit 100');
            return http.Response(
              '{"data":{"id":"s1","name":"Edit 100","version":1}}',
              201,
            );
          }),
        ),
      );
      expect(count, 1);
      // Synthetic metadata only; no user data or keys are logged.
      debugPrint(
        jsonEncode({
          'scenario': '100_offline_edits',
          'baseline_operations_per_collection': 101,
          'compacted_operations_per_collection': 1,
          'academic_http_requests': count,
          'local_elapsed_ms': watch.elapsedMilliseconds,
        }),
      );
    },
  );

  testWidgets('clinical checkpoint is atomic when window metadata fails', (
    tester,
  ) async {
    final db = await AppDatabase.database;
    await AppDatabase.setMetadata('last_sync_time', '2026-10-01T00:00:00Z');
    await db.execute(
      "CREATE TRIGGER reject_clinical_window BEFORE INSERT ON metadata "
      "WHEN NEW.key = 'appointments:window_day' BEGIN SELECT RAISE(ABORT, 'window failure'); END",
    );
    try {
      await expectLater(
        AppDatabase.commitClinicalCheckpoint(
          serverTime: '2026-10-08T12:00:00Z',
          windowDay: '2026-10-8',
          expectedGeneration: AppDatabase.captureActiveDataGeneration(),
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        await AppDatabase.getMetadata('last_sync_time'),
        '2026-10-01T00:00:00Z',
      );
      expect(await AppDatabase.getMetadata('appointments:window_day'), isNull);
    } finally {
      await db.execute('DROP TRIGGER reject_clinical_window');
    }
  });

  testWidgets(
    'account switch blocks old delta and ACK while preserving owner outbox',
    (tester) async {
      const other = 'clinical_event_isolation_B';
      final root = await getDatabasesPath();
      Future<void> removeOther() async {
        await AppDatabase.close();
        await deleteDatabase(p.join(root, 'aqua_account_$other.db'));
        await DatabaseKeyService.deleteForAccount(other);
      }

      await AppDatabase.insertPatient({'id': 'private-A', 'name': 'A only'});
      final pending = (await LocalDatabaseService.getPendingQueue(
        claim: true,
      )).single;
      final generation = AppDatabase.captureActiveDataGeneration();
      await AppDatabase.close();
      await AppDatabase.activateAccount(
        accountId: other,
        clinicalScopeVersion: 1,
      );
      try {
        await expectLater(
          AppDatabase.upsertPatientFromSync({
            'id': 'private-A',
            'name': 'Late A',
            'version': 2,
            'updated_at': '2026-10-08T12:00:00Z',
          }, expectedGeneration: generation),
          throwsA(isA<StaleAccountDataException>()),
        );
        await expectLater(
          LocalDatabaseService.completeClinicalOperation(pending, {
            'version': 2,
          }, expectedGeneration: generation),
          throwsA(isA<StaleAccountDataException>()),
        );
        expect(await AppDatabase.getAllPatients(), isEmpty);
        expect(await LocalDatabaseService.getPendingQueue(), isEmpty);
        expect(await AppDatabase.getMetadata('last_sync_time'), isNull);
      } finally {
        await removeOther();
        await AppDatabase.activateAccount(
          accountId: account,
          clinicalScopeVersion: 1,
        );
      }
      expect((await AppDatabase.getAllPatients()).single['name'], 'A only');
      expect(
        (await LocalDatabaseService.getPendingQueue()).single.operationId,
        pending.operationId,
      );
    },
  );

  testWidgets('switch during SQLCipher transaction rolls back before commit', (
    tester,
  ) async {
    await deliveredPatient('p1');
    final db = await AppDatabase.database;
    final generation = AppDatabase.captureActiveDataGeneration();
    final entered = Completer<void>();
    final release = Completer<void>();
    final mutation = db.transaction((txn) async {
      AppDatabase.ensureDataGeneration(generation);
      await txn.update(
        'patients',
        {'name': 'Must roll back'},
        where: 'id = ?',
        whereArgs: ['p1'],
      );
      entered.complete();
      await release.future;
      AppDatabase.ensureDataGeneration(generation);
    });
    final assertion = expectLater(
      mutation,
      throwsA(isA<StaleAccountDataException>()),
    );
    await entered.future;
    final closing = AppDatabase.close();
    release.complete();
    await assertion;
    await closing;
    await AppDatabase.activateAccount(
      accountId: account,
      clinicalScopeVersion: 1,
    );
    expect((await AppDatabase.getAllPatients()).single['name'], 'Initial');
  });

  testWidgets('newer server versions win over a device clock skew', (
    tester,
  ) async {
    await deliveredPatient('p1');
    final db = await AppDatabase.database;
    await db.update(
      'patients',
      {'updated_at': '2099-01-01T00:00:00Z'},
      where: 'id = ?',
      whereArgs: ['p1'],
    );
    final local = Map<String, dynamic>.from(
      (await db.query('patients')).single,
    );
    await AppDatabase.upsertPatientFromSync({
      ...local,
      'name': 'Server version 8',
      'version': 8,
      'updated_at': '2026-10-08T12:00:00Z',
    });
    expect(
      (await AppDatabase.getAllPatients()).single['name'],
      'Server version 8',
    );
    await AppDatabase.upsertPatientFromSync({
      ...local,
      'name': 'Stale version 7',
      'version': 7,
      'updated_at': '2099-02-01T00:00:00Z',
    });
    expect(
      (await AppDatabase.getAllPatients()).single['name'],
      'Server version 8',
    );
  });

  testWidgets(
    'ACK advances a never-attempted following delete without changing its UUID',
    (tester) async {
      await deliveredPatient('p1');
      await AppDatabase.updatePatient('p1', {'name': 'Offline update'});
      final update = (await LocalDatabaseService.getPendingQueue(
        claim: true,
      )).single;
      await AppDatabase.softDeletePatient('p1');
      final db = await AppDatabase.database;
      final deletion = (await db.query(
        'sync_queue',
        where: "operation = 'delete'",
      )).single;
      expect((await body(deletion))['version'], 7);
      await LocalDatabaseService.completeClinicalOperation(update, {
        'version': 8,
      }, expectedGeneration: AppDatabase.captureActiveDataGeneration());
      final after = (await db.query('sync_queue')).single;
      expect(after['operation_id'], deletion['operation_id']);
      expect((await body(after))['version'], 8);
      expect(await AppDatabase.getPatientById('p1'), isNull);
    },
  );

  testWidgets(
    'clinic switch quarantines old scope outbox and resets checkpoint',
    (tester) async {
      await AppDatabase.activateAccount(
        accountId: account,
        clinicalScopeVersion: 1,
        clinicId: 'clinic-A',
        previousClinicId: 'clinic-A',
      );
      await AppDatabase.insertPatient({
        'id': 'clinic-A-patient',
        'name': 'Clinic A only',
      });
      await AppDatabase.setMetadata('last_sync_time', '2026-10-01T00:00:00Z');
      final generation = AppDatabase.captureActiveDataGeneration();
      final result = await AppDatabase.activateAccount(
        accountId: account,
        clinicalScopeVersion: 1,
        clinicId: 'clinic-B',
      );
      expect(result.scopeChanged, isTrue);
      expect(AppDatabase.dataGeneration, greaterThan(generation));
      expect(await LocalDatabaseService.getPendingQueue(), isEmpty);
      expect(await AppDatabase.getAllPatients(), isEmpty);
      expect(await AppDatabase.getMetadata('last_sync_time'), isNull);
      expect(await AppDatabase.getMetadata('clinical_clinic_id'), 'clinic-B');
      final recovery = (await (await AppDatabase.database).query(
        'clinical_recovery',
      )).single;
      final snapshot = jsonDecode(recovery['payload'] as String);
      expect(snapshot['clinic_id'], 'clinic-A');
      expect((snapshot['operations'] as List), hasLength(1));
      expect((snapshot['patients'] as List).single['name'], 'Clinic A only');
    },
  );
}
