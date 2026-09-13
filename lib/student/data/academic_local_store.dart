import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/data/api_request_queue.dart';
import 'package:uuid/uuid.dart';

/// Snapshots and mutations share the account's encrypted database. A single
/// transaction commits the visible value together with its pending operation.
class AcademicLocalStore {
  static Future<void> retryPending() async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final db = await AppDatabase.database;
    await _schema(db);
    AppDatabase.ensureDataGeneration(generation);
    await db.update('academic_outbox', {'error': null});
  }

  static Future<void> discardPending() async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final db = await AppDatabase.database;
    await _schema(db);
    await db.transaction((txn) async {
      AppDatabase.ensureDataGeneration(generation);
      await txn.delete('academic_outbox');
      await txn.delete('academic_snapshots');
    });
  }

  static Future<void> _schema(Database db) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS academic_snapshots '
      '(collection TEXT PRIMARY KEY, data TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS academic_outbox '
      '(sequence INTEGER PRIMARY KEY AUTOINCREMENT, operation_id TEXT UNIQUE, '
      'collection TEXT, record_id TEXT, method TEXT, path TEXT, body TEXT, '
      'optimistic TEXT, error TEXT)',
    );
  }

  static Future<List<Map<String, dynamic>>> read(String collection) async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final db = await AppDatabase.database;
    await _schema(db);
    AppDatabase.ensureDataGeneration(generation);
    final rows = await db.query(
      'academic_snapshots',
      where: 'collection = ?',
      whereArgs: [collection],
    );
    AppDatabase.ensureDataGeneration(generation);
    return rows.isEmpty
        ? []
        : (jsonDecode(rows.first['data'] as String) as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
  }

  static String _id(String collection, Map<String, dynamic> row) =>
      row[collection == 'enrollments' ? 'enrollmentId' : 'id'].toString();

  static Future<void> enqueue(
    String collection,
    String id,
    String method,
    String path,
    Map<String, dynamic> body,
    Map<String, dynamic>? optimistic,
  ) async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final db = await AppDatabase.database;
    await _schema(db);
    await db.transaction((txn) async {
      AppDatabase.ensureDataGeneration(generation);
      final stored = await txn.query(
        'academic_snapshots',
        where: 'collection = ?',
        whereArgs: [collection],
      );
      final rows = stored.isEmpty
          ? <dynamic>[]
          : jsonDecode(stored.first['data'] as String) as List;
      rows.removeWhere(
        (row) => _id(collection, Map<String, dynamic>.from(row as Map)) == id,
      );
      if (optimistic != null) rows.add(optimistic);
      await txn.insert('academic_snapshots', {
        'collection': collection,
        'data': jsonEncode(rows),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('academic_outbox', {
        'operation_id': const Uuid().v4(),
        'collection': collection,
        'record_id': id,
        'method': method,
        'path': path,
        'body': jsonEncode(body),
        'optimistic': optimistic == null ? null : jsonEncode(optimistic),
      });
    });
  }

  static Future<void> replace(
    String collection,
    List<Map<String, dynamic>> remote,
    int generation,
  ) async {
    final db = await AppDatabase.database;
    await _schema(db);
    await db.transaction((txn) async {
      AppDatabase.ensureDataGeneration(generation);
      final values = {for (final row in remote) _id(collection, row): row};
      final pending = await txn.query(
        'academic_outbox',
        where: 'collection = ?',
        whereArgs: [collection],
        orderBy: 'sequence',
      );
      for (final operation in pending) {
        final id = operation['record_id'] as String;
        values.remove(id);
        if (operation['optimistic'] != null) {
          values[id] = Map<String, dynamic>.from(
            jsonDecode(operation['optimistic'] as String) as Map,
          );
        }
      }
      await txn.insert('academic_snapshots', {
        'collection': collection,
        'data': jsonEncode(values.values.toList()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  static Future<void> flush() async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final db = await AppDatabase.database;
    await _schema(db);
    AppDatabase.ensureDataGeneration(generation);
    final operations = await db.query('academic_outbox', orderBy: 'sequence');
    String? firstPermanentError;
    for (final operation in operations) {
      AppDatabase.ensureDataGeneration(generation);
      if (operation['error'] != null) {
        firstPermanentError ??= operation['error'].toString();
        continue;
      }
      final headers = {'Idempotency-Key': operation['operation_id'] as String};
      final path = operation['path'] as String;
      final body = Map<String, dynamic>.from(
        jsonDecode(operation['body'] as String) as Map,
      );
      try {
        final api = ApiClient.instance;
        switch (operation['method']) {
          case 'POST':
            await api.post(path, body: body, headers: headers, maxRetries: 0);
          case 'PUT':
            await api.put(path, body: body, headers: headers, maxRetries: 0);
          case 'PATCH':
            await api.patch(path, body: body, headers: headers, maxRetries: 0);
          case 'DELETE':
            await api.delete(path, headers: headers, maxRetries: 0);
        }
        AppDatabase.ensureDataGeneration(generation);
        await db.delete(
          'academic_outbox',
          where: 'sequence = ?',
          whereArgs: [operation['sequence']],
        );
      } on ApiException catch (error) {
        AppDatabase.ensureDataGeneration(generation);
        if ([403, 404, 409, 422].contains(error.statusCode)) {
          final message = '${error.statusCode}: ${error.message}';
          await db.update(
            'academic_outbox',
            {'error': message},
            where: 'sequence = ?',
            whereArgs: [operation['sequence']],
          );
          firstPermanentError ??= message;
          continue;
        }
        rethrow;
      }
    }
    if (firstPermanentError != null) {
      throw StateError('عملية دراسية تحتاج مراجعة: $firstPermanentError');
    }
  }
}
