import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/data/database_key_service.dart';
import 'package:studentry/shared/data/local_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('v7 outbox upgrades to durable v8 backoff columns', (
    tester,
  ) async {
    const accountId = 'backpressure_migration_test';
    await AppDatabase.close();
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'aqua_account_$accountId.db');
    await deleteDatabase(path);
    await DatabaseKeyService.deleteForAccount(accountId);
    final key = await DatabaseKeyService.getOrCreateForAccount(accountId);

    final legacy = await openDatabase(
      path,
      password: key,
      version: 7,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operation TEXT NOT NULL,
            table_name TEXT NOT NULL,
            record_id TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL,
            retry_count INTEGER DEFAULT 0,
            status TEXT DEFAULT 'pending',
            operation_id TEXT
          )
        ''');
      },
    );
    await legacy.insert('sync_queue', {
      'operation': 'insert',
      'table_name': 'patients',
      'record_id': '80000000-0000-0000-0000-000000000001',
      'payload': 'encrypted-placeholder',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'retry_count': 2,
      'status': 'failed',
      'operation_id': '80000000-0000-0000-0000-000000000002',
    });
    await legacy.close();

    try {
      await AppDatabase.activateAccount(
        accountId: accountId,
        clinicalScopeVersion: 1,
      );
      final upgraded = await AppDatabase.database;
      final version = await upgraded.rawQuery('PRAGMA user_version');
      expect(version.first.values.first, 8);

      final columns = (await upgraded.rawQuery(
        'PRAGMA table_info(sync_queue)',
      )).map((row) => row['name']).toSet();
      expect(columns, contains('next_attempt_at'));
      expect(columns, contains('last_error'));
      expect(columns, contains('last_http_status'));

      final migrated = await upgraded.query('sync_queue', limit: 1);
      expect(migrated.single['status'], 'pending');
      expect(migrated.single['retry_count'], 0);

      final nextAttempt = await LocalDatabaseService.scheduleRetry(
        migrated.single['id']! as int,
        delay: const Duration(seconds: 30),
        httpStatus: 429,
        error: 'busy',
      );
      expect(nextAttempt, isNotNull);
      final deferred = await upgraded.query('sync_queue', limit: 1);
      expect(deferred.single['status'], 'retrying');
      expect(deferred.single['retry_count'], 1);
      expect(deferred.single['last_http_status'], 429);
      expect(deferred.single['last_error'], 'busy');
      expect(deferred.single['next_attempt_at'], isNotNull);

      final summary = await LocalDatabaseService.getQueueSummary();
      expect(summary.retrying, 1);
      expect(summary.waiting, 1);
    } finally {
      await AppDatabase.close();
      await deleteDatabase(path);
      await DatabaseKeyService.deleteForAccount(accountId);
    }
  });
}
