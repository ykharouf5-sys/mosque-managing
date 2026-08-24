import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'app_database.dart';
import 'encryption_service.dart';

class SyncQueueItem {
  final int id;
  final String operation;
  final String tableName;
  final String recordId;
  final String payload;
  final String operationId;

  SyncQueueItem({
    required this.id,
    required this.operation,
    required this.tableName,
    required this.recordId,
    required this.payload,
    required this.operationId,
  });

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id'] as int,
      operation: map['operation'] as String,
      tableName: map['table_name'] as String,
      recordId: map['record_id'] as String,
      payload: map['payload'] as String,
      operationId: (map['operation_id'] as String?) ?? const Uuid().v4(),
    );
  }
}

class LocalDatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  static Future<Database> _init({int version = 1}) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'dentalcare_sync.db');
    return openDatabase(
      path,
      version: version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operation TEXT NOT NULL,
            collection TEXT NOT NULL,
            docId TEXT,
            parentDoc TEXT,
            subcollection TEXT,
            data TEXT,
            createdAt INTEGER NOT NULL,
            retries INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ── Metadata ──
  static Future<void> setMetadata(String key, String value) async {
    final db = await database;
    await db.insert('metadata', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<String?> getMetadata(String key) async {
    final db = await database;
    final rows = await db.query('metadata', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String;
  }

  // ── Sync Queue ──
  static const int _maxQueueItems = 1000;
  static const int _ttlDays = 7;

  /// Remove items older than TTL or when queue exceeds max size.
  static Future<void> _pruneQueue() async {
    final db = await database;

    // Remove items older than TTL
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - (_ttlDays * 86400000);
    await db.delete('sync_queue', where: 'createdAt < ?', whereArgs: [cutoff]);

    // Remove oldest items if queue exceeds max size
    final count = await getPendingSyncCount();
    if (count > _maxQueueItems) {
      final excess = count - _maxQueueItems;
      await db.rawDelete(
        'DELETE FROM sync_queue WHERE id IN (SELECT id FROM sync_queue ORDER BY createdAt ASC LIMIT ?)',
        [excess],
      );
    }
  }

  static Future<void> enqueueSync({
    required String operation,
    required String collection,
    String? docId,
    String? parentDoc,
    String? subcollection,
    Map<String, dynamic>? data,
  }) async {
    final db = await database;
    String? encryptedData;
    if (data != null) {
      final plain = jsonEncode(data);
      encryptedData = await EncryptionService.encrypt(plain);
    }
    await db.insert('sync_queue', {
      'operation': operation,
      'collection': collection,
      'docId': docId,
      'parentDoc': parentDoc,
      'subcollection': subcollection,
      'data': encryptedData,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'retries': 0,
    });

    // Prune old/excess items after each enqueue
    await _pruneQueue();
  }

  static Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await database;
    final rows = await db.query('sync_queue', orderBy: 'createdAt ASC');
    final decrypted = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row['data'] != null) {
        try {
          final decryptedData = await EncryptionService.decrypt(
            row['data'] as String,
          );
          final parsed = jsonDecode(decryptedData) as Map<String, dynamic>;
          row['data'] = jsonEncode(parsed);
        } catch (_) {}
      }
      decrypted.add(row);
    }
    return decrypted;
  }

  static Future<void> removeSyncItem(int id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> incrementRetry(int id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE sync_queue SET retries = retries + 1 WHERE id = ?',
      [id],
    );
  }

  static Future<int> getPendingSyncCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM sync_queue');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<void> clearSyncQueue() async {
    final db = await database;
    await db.delete('sync_queue');
  }

  // ── New Sync Queue (uses AppDatabase's sync_queue table) ──

  static Future<void> addToQueue({
    required String operation,
    required String tableName,
    required String recordId,
    required String payload,
  }) async {
    try {
      final db = await AppDatabase.database;
      final encryptedPayload = await EncryptionService.encrypt(payload);
      await db.insert('sync_queue', {
        'operation': operation,
        'table_name': tableName,
        'record_id': recordId,
        'payload': encryptedPayload,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'retry_count': 0,
        'status': 'pending',
        'operation_id': const Uuid().v4(),
      });
    } catch (e) {
      debugPrint('addToQueue error: $e');
    }
  }

  static Future<List<SyncQueueItem>> getPendingQueue({int limit = 50}) async {
    try {
      final db = await AppDatabase.database;
      final rows = await db.query(
        'sync_queue',
        where: 'status = ?',
        whereArgs: ['pending'],
        orderBy: 'created_at ASC',
        limit: limit,
      );
      final decrypted = <SyncQueueItem>[];
      for (final row in rows) {
        try {
          row['payload'] = await EncryptionService.decrypt(
            row['payload'] as String,
          );
          decrypted.add(SyncQueueItem.fromMap(row));
        } catch (_) {
          await db.update(
            'sync_queue',
            {'status': 'failed', 'retry_count': 99},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
      return decrypted;
    } catch (e) {
      debugPrint('getPendingQueue error: $e');
      return [];
    }
  }

  static Future<void> markAsCompleted(int id) async {
    try {
      final db = await AppDatabase.database;
      await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('markAsCompleted error: $e');
    }
  }

  static Future<void> markAsFailed(int id) async {
    try {
      final db = await AppDatabase.database;
      final rows = await db.query(
        'sync_queue',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final retryCount = (rows.first['retry_count'] as int?) ?? 0;
      final nextStatus = retryCount >= 2 ? 'failed' : 'pending';
      await db.rawUpdate(
        'UPDATE sync_queue SET retry_count = retry_count + 1, status = ? WHERE id = ?',
        [nextStatus, id],
      );
    } catch (e) {
      debugPrint('markAsFailed error: $e');
    }
  }

  static Future<void> resetFailedItems() async {
    try {
      final db = await AppDatabase.database;
      await db.rawUpdate(
        "UPDATE sync_queue SET retry_count = 0, status = 'pending' WHERE status = 'failed'",
      );
    } catch (e) {
      debugPrint('resetFailedItems error: $e');
    }
  }

  // ── Sync time ──

  static Future<String> getLastSyncTime() async {
    final value = await AppDatabase.getMetadata('last_sync_time');
    return value ?? '1970-01-01T00:00:00.000';
  }

  static Future<void> setLastSyncTime(String value) async {
    await AppDatabase.setMetadata('last_sync_time', value);
  }

  // ── Pull helpers ──

  static Future<void> upsertPatientFromSync(Map<String, dynamic> row) async {
    final data = row['data'] is Map
        ? Map<String, dynamic>.from(row['data'] as Map)
        : Map<String, dynamic>.from(row);
    data['id'] = row['id'];
    data['updated_at'] =
        row['updated_at'] ?? DateTime.now().toUtc().toIso8601String();
    data['deleted_at'] = row['deleted_at'];
    data['device_id'] = row['device_id'] ?? 'server';
    data['version'] = (row['version'] as num?)?.toInt() ?? 1;
    data.remove('clinic_id');
    data.remove('created_at');
    await AppDatabase.upsertPatientFromSync(data);
  }

  static Future<void> upsertAppointmentFromSync(
    Map<String, dynamic> row,
  ) async {
    final data = row['data'] is Map
        ? Map<String, dynamic>.from(row['data'] as Map)
        : Map<String, dynamic>.from(row);
    data['id'] = row['id'];
    data['updated_at'] =
        row['updated_at'] ?? DateTime.now().toUtc().toIso8601String();
    data['deleted_at'] = row['deleted_at'];
    data['device_id'] = row['device_id'] ?? 'server';
    data['version'] = (row['version'] as num?)?.toInt() ?? 1;
    data.remove('clinic_id');
    data.remove('created_at');
    await AppDatabase.upsertAppointmentFromSync(data);
  }
}
