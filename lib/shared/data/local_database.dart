import 'dart:convert';
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
  // The encrypted AppDatabase is the only local source of truth. The former
  // secondary `dentalcare_sync.db` queue was unencrypted and account-agnostic.
  static const _patientColumns = {
    'id',
    'name',
    'phone',
    'age',
    'address',
    'registrationDate',
    'notes',
    'photoUrl',
    'amountDue',
    'amountPaid',
    'todayPayment',
    'appointmentDate',
    'treatmentPlan',
    'photos',
    'updated_at',
    'deleted_at',
    'device_id',
    'version',
  };
  static const _appointmentColumns = {
    'id',
    'patientId',
    'patientName',
    'time',
    'status',
    'treatment',
    'date',
    'reminderSent',
    'notificationSent',
    'updated_at',
    'deleted_at',
    'device_id',
    'version',
  };

  static Future<void> addToQueue({
    required String operation,
    required String tableName,
    required String recordId,
    required String payload,
    int? expectedGeneration,
  }) async {
    try {
      final generation =
          expectedGeneration ?? AppDatabase.captureActiveDataGeneration();
      final db = await AppDatabase.database;
      final encryptedPayload = await EncryptionService.encrypt(payload);
      AppDatabase.ensureDataGeneration(generation);
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
    } catch (_) {}
  }

  static Future<List<SyncQueueItem>> getPendingQueue({
    int limit = 50,
    int? expectedGeneration,
  }) async {
    try {
      final generation =
          expectedGeneration ?? AppDatabase.captureActiveDataGeneration();
      final db = await AppDatabase.database;
      final rows = await db.query(
        'sync_queue',
        where: 'status = ?',
        whereArgs: ['pending'],
        orderBy: 'created_at ASC',
        limit: limit,
      );
      final decrypted = <SyncQueueItem>[];
      for (final storedRow in rows) {
        final row = Map<String, Object?>.from(storedRow);
        try {
          row['payload'] = await EncryptionService.decrypt(
            row['payload'] as String,
          );
          decrypted.add(SyncQueueItem.fromMap(Map<String, dynamic>.from(row)));
        } catch (_) {
          AppDatabase.ensureDataGeneration(generation);
          await db.update(
            'sync_queue',
            {'status': 'failed', 'retry_count': 99},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
      AppDatabase.ensureDataGeneration(generation);
      return decrypted;
    } catch (_) {
      return [];
    }
  }

  static Future<void> markAsCompleted(int id, {int? expectedGeneration}) async {
    try {
      final generation =
          expectedGeneration ?? AppDatabase.captureActiveDataGeneration();
      final db = await AppDatabase.database;
      AppDatabase.ensureDataGeneration(generation);
      await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  static Future<void> markAsFailed(int id, {int? expectedGeneration}) async {
    try {
      final generation =
          expectedGeneration ?? AppDatabase.captureActiveDataGeneration();
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
      AppDatabase.ensureDataGeneration(generation);
      await db.rawUpdate(
        'UPDATE sync_queue SET retry_count = retry_count + 1, status = ? WHERE id = ?',
        [nextStatus, id],
      );
    } catch (_) {}
  }

  static Future<void> resetFailedItems({int? expectedGeneration}) async {
    try {
      final generation =
          expectedGeneration ?? AppDatabase.captureActiveDataGeneration();
      final db = await AppDatabase.database;
      AppDatabase.ensureDataGeneration(generation);
      await db.rawUpdate(
        "UPDATE sync_queue SET retry_count = 0, status = 'pending' WHERE status = 'failed'",
      );
    } catch (_) {}
  }

  // ── Sync time ──

  static Future<String> getLastSyncTime() async {
    final value = await AppDatabase.getMetadata('last_sync_time');
    return value ?? '1970-01-01T00:00:00.000';
  }

  static Future<void> setLastSyncTime(
    String value, {
    int? expectedGeneration,
  }) async {
    await AppDatabase.setMetadata(
      'last_sync_time',
      value,
      expectedGeneration: expectedGeneration,
    );
  }

  // ── Pull helpers ──

  static Future<void> upsertPatientFromSync(
    Map<String, dynamic> row, {
    int? expectedGeneration,
  }) async {
    final data = row['data'] is Map
        ? Map<String, dynamic>.from(row['data'] as Map)
        : Map<String, dynamic>.from(row);
    data['id'] = row['id'];
    data['updated_at'] =
        row['updated_at'] ?? DateTime.now().toUtc().toIso8601String();
    data['deleted_at'] = row['deleted_at'];
    data['device_id'] = row['device_id'] ?? 'server';
    data['version'] = (row['version'] as num?)?.toInt() ?? 1;
    data['treatmentPlan'] = _jsonColumn(data['treatmentPlan']);
    data['photos'] = _jsonColumn(data['photos']);
    data.removeWhere((key, _) => !_patientColumns.contains(key));
    await AppDatabase.upsertPatientFromSync(
      data,
      expectedGeneration: expectedGeneration,
    );
  }

  static Future<void> upsertAppointmentFromSync(
    Map<String, dynamic> row, {
    int? expectedGeneration,
  }) async {
    final data = row['data'] is Map
        ? Map<String, dynamic>.from(row['data'] as Map)
        : Map<String, dynamic>.from(row);
    data['id'] = row['id'];
    data['updated_at'] =
        row['updated_at'] ?? DateTime.now().toUtc().toIso8601String();
    data['deleted_at'] = row['deleted_at'];
    data['device_id'] = row['device_id'] ?? 'server';
    data['version'] = (row['version'] as num?)?.toInt() ?? 1;
    data['reminderSent'] = _sqliteBool(data['reminderSent']);
    data['notificationSent'] = _sqliteBool(data['notificationSent']);
    data.removeWhere((key, _) => !_appointmentColumns.contains(key));
    await AppDatabase.upsertAppointmentFromSync(
      data,
      expectedGeneration: expectedGeneration,
    );
  }

  static String _jsonColumn(dynamic value) {
    if (value is String) return value;
    return jsonEncode(value ?? const []);
  }

  static int _sqliteBool(dynamic value) => value == true || value == 1 ? 1 : 0;
}
