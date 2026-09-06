import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/data/database_key_service.dart';
import 'package:studentry/student/data/academic_local_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('academic offline writes survive restart and isolate accounts', (
    tester,
  ) async {
    const accounts = ['academic_offline_test_a', 'academic_offline_test_b'];
    final root = await getDatabasesPath();
    Future<void> clean() async {
      await AppDatabase.close();
      for (final account in accounts) {
        await deleteDatabase(p.join(root, 'aqua_account_$account.db'));
        await DatabaseKeyService.deleteForAccount(account);
      }
    }

    await clean();
    try {
      await AppDatabase.activateAccount(
        accountId: accounts[0],
        clinicalScopeVersion: 1,
      );
      await AcademicLocalStore.enqueue(
        'subjects',
        's1',
        'POST',
        '/academic/subjects',
        {'id': 's1', 'name': 'offline'},
        {'id': 's1', 'name': 'offline', 'version': 1},
      );
      expect(
        (await AcademicLocalStore.read('subjects')).single['name'],
        'offline',
      );
      var db = await AppDatabase.database;
      final operationId = (await db.query(
        'academic_outbox',
      )).single['operation_id'];
      expect(operationId, isNotEmpty);
      await AppDatabase.close();
      await AppDatabase.activateAccount(
        accountId: accounts[0],
        clinicalScopeVersion: 1,
      );
      db = await AppDatabase.database;
      expect(
        (await db.query('academic_outbox')).single['operation_id'],
        operationId,
      );

      // A refresh must not erase a newer, unuploaded edit.
      await AcademicLocalStore.replace('subjects', [
        {'id': 's1', 'name': 'remote'},
      ], AppDatabase.captureActiveDataGeneration());
      expect(
        (await AcademicLocalStore.read('subjects')).single['name'],
        'offline',
      );
      final previousGeneration = AppDatabase.captureActiveDataGeneration();
      await AppDatabase.activateAccount(
        accountId: accounts[1],
        clinicalScopeVersion: 1,
      );
      expect(await AcademicLocalStore.read('subjects'), isEmpty);
      expect(
        await (await AppDatabase.database).query('academic_outbox'),
        isEmpty,
      );
      await expectLater(
        AcademicLocalStore.replace('subjects', [
          {'id': 'leak'},
        ], previousGeneration),
        throwsA(isA<StaleAccountDataException>()),
      );
      expect(await AcademicLocalStore.read('subjects'), isEmpty);

      await AppDatabase.activateAccount(
        accountId: accounts[0],
        clinicalScopeVersion: 1,
      );
      expect(
        (await AcademicLocalStore.read('subjects')).single['name'],
        'offline',
      );
      db = await AppDatabase.database;
      // Force journal insertion to fail: the visible edit must roll back too.
      await db.execute(
        "CREATE TRIGGER reject_test_write BEFORE INSERT ON academic_outbox BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      await expectLater(
        AcademicLocalStore.enqueue(
          'subjects',
          's2',
          'POST',
          '/academic/subjects',
          {'id': 's2'},
          {'id': 's2'},
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect((await AcademicLocalStore.read('subjects')).length, 1);
      expect((await db.query('academic_outbox')).length, 1);
      await db.execute('DROP TRIGGER reject_test_write');
      await AcademicLocalStore.enqueue(
        'subjects',
        's1',
        'DELETE',
        '/academic/subjects/s1',
        {},
        null,
      );
      await AcademicLocalStore.replace('subjects', [
        {'id': 's1', 'name': 'remote'},
      ], AppDatabase.captureActiveDataGeneration());
      expect(await AcademicLocalStore.read('subjects'), isEmpty);
      expect((await db.query('academic_outbox')).length, 2);
    } finally {
      await clean();
    }
  });
}
