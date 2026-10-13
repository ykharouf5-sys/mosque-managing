import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/data/database_key_service.dart';
import 'package:studentry/shared/data/local_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'REST ack preserves later offline edits and advances their version atomically',
    (tester) async {
      const account = 'patient_rest_outbox_test';
      final root = await getDatabasesPath();
      Future<void> clean() async {
        await AppDatabase.close();
        await deleteDatabase(p.join(root, 'aqua_account_$account.db'));
        await DatabaseKeyService.deleteForAccount(account);
      }

      await clean();
      try {
        await AppDatabase.activateAccount(
          accountId: account,
          clinicalScopeVersion: 1,
        );
        await AppDatabase.insertPatient({
          'id': 'test-patient',
          'name': 'Original',
        });
        // Freeze the create exactly when transport would start. Later edits
        // may coalesce with each other but must not change the sent create.
        await LocalDatabaseService.getPendingQueue(claim: true);
        await AppDatabase.updatePatient('test-patient', {
          'name': 'Offline edit A',
        });
        await AppDatabase.updatePatient('test-patient', {
          'name': 'Offline edit B',
        });
        var db = await AppDatabase.database;
        final original = Map<String, dynamic>.from(
          (await db.query('patients')).single,
        );
        var head = (await LocalDatabaseService.getPendingQueue()).single;
        expect(head.operation, 'insert');
        final generation = AppDatabase.captureActiveDataGeneration();
        await LocalDatabaseService.completePatientOperation(head, {
          ...original,
          'name': 'Original',
          'version': 1,
          'updated_at': '2099-01-01T00:00:00.000Z',
        }, expectedGeneration: generation);
        expect((await db.query('patients')).single['name'], 'Offline edit B');
        head = (await LocalDatabaseService.getPendingQueue()).single;
        expect(jsonDecode(head.payload)['version'], 1);
        final key = head.operationId;
        // A newer timestamp from another device cannot erase pending local work.
        await AppDatabase.upsertPatientFromSync({
          ...original,
          'name': 'Other device',
          'version': 99,
          'updated_at': '2099-02-01T00:00:00.000Z',
        });
        expect((await db.query('patients')).single['name'], 'Offline edit B');
        await db.execute(
          "CREATE TRIGGER reject_patient_ack BEFORE DELETE ON sync_queue BEGIN SELECT RAISE(ABORT, 'ack failure'); END",
        );
        await expectLater(
          LocalDatabaseService.completePatientOperation(head, {
            ...original,
            'name': 'Offline edit A',
            'version': 2,
            'updated_at': '2099-01-01T00:00:00.000Z',
          }, expectedGeneration: generation),
          throwsA(isA<DatabaseException>()),
        );
        expect((await db.query('patients')).single['version'], 1);
        expect(
          (await LocalDatabaseService.getPendingQueue()).single.operationId,
          key,
        );
        await db.execute('DROP TRIGGER reject_patient_ack');
        await LocalDatabaseService.getPendingQueue(claim: true);
        await AppDatabase.updatePatient('test-patient', {
          'name': 'Offline edit C',
        });
        await LocalDatabaseService.completePatientOperation(head, {
          ...original,
          'name': 'Offline edit B',
          'version': 2,
          'updated_at': '2099-01-01T00:00:00.000Z',
        }, expectedGeneration: generation);
        expect((await db.query('patients')).single['name'], 'Offline edit C');
        head = (await LocalDatabaseService.getPendingQueue()).single;
        expect(jsonDecode(head.payload)['version'], 2);
        await LocalDatabaseService.scheduleRetry(
          head.id,
          delay: const Duration(hours: 1),
        );
        await AppDatabase.updatePatient('test-patient', {
          'name': 'Offline edit D',
        });
        expect(await LocalDatabaseService.getPendingQueue(), isEmpty);
        await AppDatabase.close();
        await AppDatabase.activateAccount(
          accountId: account,
          clinicalScopeVersion: 1,
        );
        db = await AppDatabase.database;
        expect((await db.query('patients')).single['name'], 'Offline edit D');
        expect((await db.query('sync_queue')).length, 2);
        expect(await LocalDatabaseService.getPendingQueue(), isEmpty);
      } finally {
        await clean();
      }
    },
  );
}
