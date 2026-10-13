import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/data/api_request_queue.dart';
import 'package:uuid/uuid.dart';

/// Snapshots and mutations share the account's encrypted database. A single
/// transaction commits the visible value together with its pending operation.
class AcademicLocalStore {
  static Future<void>? _flushing;
  static int? _flushGeneration;
  static Future<void> retryPending() async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final db = await AppDatabase.database;
    AppDatabase.ensureDataGeneration(generation);
    await db.update('academic_outbox', {'error': null});
  }

  static Future<void> discardPending() async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final db = await AppDatabase.database;
    await db.transaction((txn) async {
      AppDatabase.ensureDataGeneration(generation);
      await txn.delete('academic_outbox');
      await txn.delete('academic_snapshots');
      await txn.delete(
        'metadata',
        where: 'key = ?',
        whereArgs: ['academic_sync_checkpoint'],
      );
    });
  }

  static Future<List<Map<String, dynamic>>> read(String collection) async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final db = await AppDatabase.database;
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

  static Future<Map<String, dynamic>?> enqueue(
    String collection,
    String id,
    String method,
    String path,
    Map<String, dynamic> body,
    Map<String, dynamic>? optimistic,
  ) async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final db = await AppDatabase.database;
    return db.transaction((txn) async {
      AppDatabase.ensureDataGeneration(generation);
      final normalized = await _enqueueOperation(txn, {
        'operation_id': const Uuid().v4(),
        'collection': collection,
        'record_id': id,
        'method': method,
        'path': path,
        'body': jsonEncode(body),
        'optimistic': optimistic == null ? null : jsonEncode(optimistic),
        'attempted': 0,
      });
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
      if (normalized != null) rows.add(normalized);
      await txn.insert('academic_snapshots', {
        'collection': collection,
        'data': jsonEncode(rows),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return normalized;
    });
  }

  static Future<Map<String, dynamic>?> _enqueueOperation(
    Transaction txn,
    Map<String, Object?> incoming,
  ) async {
    Map<String, dynamic>? optimistic = incoming['optimistic'] == null
        ? null
        : _decode(incoming['optimistic'] as String);
    final previous = await txn.query(
      'academic_outbox',
      where: 'collection = ? AND record_id = ?',
      whereArgs: [incoming['collection'], incoming['record_id']],
      orderBy: 'sequence DESC',
      limit: 1,
    );
    Future<Map<String, dynamic>?> insert() async {
      await txn.insert('academic_outbox', incoming);
      return optimistic;
    }

    if (previous.isEmpty) return insert();
    final head = previous.single;
    if (head['attempted'] != 0 ||
        head['error'] != null ||
        !['POST', 'PUT'].contains(head['method']) ||
        !['PUT', 'DELETE'].contains(incoming['method'])) {
      return insert();
    }
    final intervening = await txn.query(
      'academic_outbox',
      where: 'sequence > ?',
      whereArgs: [head['sequence']],
    );
    for (final row in intervening) {
      if (_dependOnEachOther(head, row)) return insert();
    }
    if (head['method'] == 'POST' && incoming['method'] == 'DELETE') {
      final earlier = await txn.query(
        'academic_outbox',
        columns: ['sequence'],
        where: 'collection = ? AND record_id = ? AND sequence < ?',
        whereArgs: [head['collection'], head['record_id'], head['sequence']],
        limit: 1,
      );
      if (earlier.isNotEmpty) return insert();
      if (head['collection'] == 'subjects') {
        final related = await txn.query(
          'academic_outbox',
          where: 'collection = ?',
          whereArgs: ['enrollments'],
        );
        if (related.any((row) => _dependOnEachOther(head, row))) {
          return insert();
        }
        final snapshot = await txn.query(
          'academic_snapshots',
          where: 'collection = ?',
          whereArgs: ['enrollments'],
        );
        if (snapshot.isNotEmpty &&
            (jsonDecode(snapshot.single['data'] as String) as List).any(
              (row) => row['subjectId'] == head['record_id'],
            )) {
          return insert();
        }
      }
      await txn.delete(
        'academic_outbox',
        where: 'sequence = ?',
        whereArgs: [head['sequence']],
      );
      return null;
    }
    final oldBody = _decode(head['body'] as String);
    final newBody = _decode(incoming['body'] as String);
    final method = incoming['method'] == 'DELETE' ? 'DELETE' : head['method'];
    final merged = method == 'DELETE'
        ? <String, dynamic>{...newBody}
        : <String, dynamic>{...oldBody, ...newBody};
    if (method == 'POST') {
      merged.remove('version');
      if (optimistic != null) optimistic = {...optimistic, 'version': 1};
    } else if (oldBody['version'] is num) {
      merged['version'] = oldBody['version'];
      if (optimistic != null) {
        optimistic = {
          ...optimistic,
          'version': (oldBody['version'] as num).toInt() + 1,
        };
      }
    }
    await txn.update(
      'academic_outbox',
      {
        'method': method,
        'path': method == 'DELETE' ? incoming['path'] : head['path'],
        'body': jsonEncode(merged),
        'optimistic': optimistic == null ? null : jsonEncode(optimistic),
      },
      where: 'sequence = ?',
      whereArgs: [head['sequence']],
    );
    return optimistic;
  }

  static Map<String, dynamic> _decode(String value) =>
      Map<String, dynamic>.from(jsonDecode(value) as Map);

  static bool _dependOnEachOther(
    Map<String, Object?> left,
    Map<String, Object?> right,
  ) {
    if (left['collection'] == right['collection']) return false;
    final subject = left['collection'] == 'subjects' ? left : right;
    final enrollment = left['collection'] == 'enrollments' ? left : right;
    if (subject['collection'] != 'subjects' ||
        enrollment['collection'] != 'enrollments') {
      return true;
    }
    final body = _decode(enrollment['body'] as String);
    final view = enrollment['optimistic'] == null
        ? null
        : _decode(enrollment['optimistic'] as String);
    // A delete may omit its parent reference. Preserve ordering conservatively.
    final subjectId = body['subject_id'] ?? view?['subjectId'];
    return subjectId == null || subjectId == subject['record_id'];
  }

  static Future<void> replace(
    String collection,
    List<Map<String, dynamic>> remote,
    int generation,
  ) async {
    final db = await AppDatabase.database;
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

  static Future<String?> syncCheckpoint(int generation) async {
    final db = await AppDatabase.database;
    AppDatabase.ensureDataGeneration(generation);
    final rows = await db.query(
      'metadata',
      where: 'key = ?',
      whereArgs: ['academic_sync_checkpoint'],
    );
    AppDatabase.ensureDataGeneration(generation);
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  /// Both collections and the checkpoint commit together. A failed page or a
  /// crash leaves the previous checkpoint available for a safe replay.
  static Future<void> applySync(
    Map<String, List<Map<String, dynamic>>> changes, {
    required bool reset,
    required String? checkpoint,
    required int generation,
  }) async {
    final db = await AppDatabase.database;
    await db.transaction((txn) async {
      AppDatabase.ensureDataGeneration(generation);
      for (final collection in ['subjects', 'enrollments']) {
        final stored = await txn.query(
          'academic_snapshots',
          where: 'collection = ?',
          whereArgs: [collection],
        );
        final values = <String, Map<String, dynamic>>{};
        if (!reset && stored.isNotEmpty) {
          for (final raw
              in jsonDecode(stored.single['data'] as String) as List) {
            final row = Map<String, dynamic>.from(raw as Map);
            values[_id(collection, row)] = row;
          }
        }
        for (final change in changes[collection]!) {
          final id = change['id'] as String;
          if (change['deleted'] == true) {
            values.remove(id);
          } else {
            values[id] = Map<String, dynamic>.from(change['row'] as Map);
          }
        }
        // Read the outbox inside the final transaction, including edits that
        // were made while any of the network pages were in flight.
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
            values[id] = _decode(operation['optimistic'] as String);
          }
        }
        await txn.insert('academic_snapshots', {
          'collection': collection,
          'data': jsonEncode(values.values.toList()),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (checkpoint == null) {
        await txn.delete(
          'metadata',
          where: 'key = ?',
          whereArgs: ['academic_sync_checkpoint'],
        );
      } else {
        await txn.insert('metadata', {
          'key': 'academic_sync_checkpoint',
          'value': checkpoint,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  static Future<void> flush({ApiClient? client}) {
    final generation = AppDatabase.captureActiveDataGeneration();
    if (_flushing != null && _flushGeneration == generation) return _flushing!;
    _flushGeneration = generation;
    late final Future<void> run;
    run = _flush(generation, client ?? ApiClient.instance).whenComplete(() {
      if (identical(_flushing, run)) _flushing = null;
    });
    _flushing = run;
    return run;
  }

  static Future<void> _flush(int generation, ApiClient api) async {
    final db = await AppDatabase.database;
    AppDatabase.ensureDataGeneration(generation);
    final last = await db.query(
      'academic_outbox',
      columns: ['sequence'],
      orderBy: 'sequence DESC',
      limit: 1,
    );
    if (last.isEmpty) return;
    final through = last.single['sequence'];
    while (true) {
      AppDatabase.ensureDataGeneration(generation);
      final operation = await db.transaction((txn) async {
        AppDatabase.ensureDataGeneration(generation);
        final rows = await txn.query(
          'academic_outbox',
          where: 'sequence <= ?',
          whereArgs: [through],
          orderBy: 'sequence',
          limit: 1,
        );
        if (rows.isEmpty) return null;
        final head = rows.single;
        if (head['error'] != null) {
          throw StateError('عملية دراسية تحتاج مراجعة: ${head['error']}');
        }
        await txn.update(
          'academic_outbox',
          {'attempted': 1},
          where: 'sequence = ?',
          whereArgs: [head['sequence']],
        );
        return head;
      });
      if (operation == null) return;
      final headers = {'Idempotency-Key': operation['operation_id'] as String};
      final path = operation['path'] as String;
      final body = Map<String, dynamic>.from(
        jsonDecode(operation['body'] as String) as Map,
      );
      try {
        late final ApiResult response;
        switch (operation['method']) {
          case 'POST':
            response = await api.post(
              path,
              body: body,
              headers: headers,
              maxRetries: 0,
            );
          case 'PUT':
            response = await api.put(
              path,
              body: body,
              headers: headers,
              maxRetries: 0,
            );
          case 'PATCH':
            response = await api.patch(
              path,
              body: body,
              headers: headers,
              maxRetries: 0,
            );
          case 'DELETE':
            response = await api.delete(path, headers: headers, maxRetries: 0);
          default:
            throw StateError('Unknown academic operation method');
        }
        AppDatabase.ensureDataGeneration(generation);
        await db.transaction((txn) async {
          AppDatabase.ensureDataGeneration(generation);
          await _ack(txn, operation, response);
          await txn.delete(
            'academic_outbox',
            where: 'sequence = ?',
            whereArgs: [operation['sequence']],
          );
        });
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
          // Subsequent writes may depend on this one. Pull remains possible,
          // but flushing must wait for explicit review instead of overtaking it.
          throw StateError('عملية دراسية تحتاج مراجعة: $message');
        }
        rethrow;
      }
    }
  }

  static Future<void> _ack(
    Transaction txn,
    Map<String, Object?> operation,
    ApiResult response,
  ) async {
    final collection = operation['collection'] as String;
    final id = operation['record_id'];
    final pending = await txn.query(
      'academic_outbox',
      where: 'collection = ? AND record_id = ? AND sequence > ?',
      whereArgs: [collection, id, operation['sequence']],
      orderBy: 'sequence',
    );
    final remote = response.data is Map && response.data['data'] is Map
        ? Map<String, dynamic>.from(response.data['data'] as Map)
        : null;
    var version = (remote?['version'] as num?)?.toInt();
    Map<String, dynamic>? latest;
    var rebased = 0;
    if (version != null) {
      for (final next in pending) {
        if (next['attempted'] != 0 || next['error'] != null) break;
        final body = _decode(next['body'] as String);
        if (['PUT', 'PATCH'].contains(next['method'])) {
          body['version'] = version;
          version = version! + 1;
        }
        latest = next['optimistic'] == null
            ? null
            : _decode(next['optimistic'] as String);
        if (latest != null) latest['version'] = version;
        await txn.update(
          'academic_outbox',
          {
            'body': jsonEncode(body),
            'optimistic': latest == null ? null : jsonEncode(latest),
          },
          where: 'sequence = ?',
          whereArgs: [next['sequence']],
        );
        rebased++;
      }
    }
    // Apply canonical data only when no newer local edit exists.
    final replacement = pending.isEmpty
        ? remote
        : rebased == pending.length
        ? latest
        : null;
    if (replacement == null) return;
    final stored = await txn.query(
      'academic_snapshots',
      where: 'collection = ?',
      whereArgs: [collection],
    );
    final rows = stored.isEmpty
        ? <dynamic>[]
        : jsonDecode(stored.single['data'] as String) as List;
    rows.removeWhere(
      (row) => _id(collection, Map<String, dynamic>.from(row as Map)) == id,
    );
    if (pending.isEmpty || pending.last['optimistic'] != null) {
      rows.add(replacement);
    }
    await txn.insert('academic_snapshots', {
      'collection': collection,
      'data': jsonEncode(rows),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
