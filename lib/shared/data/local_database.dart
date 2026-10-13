import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'app_database.dart';
import 'clinical_outbox.dart';
import 'encryption_service.dart';

class SyncQueueItem {
  final int id;
  final String operation;
  final String tableName;
  final String recordId;
  final String payload;
  final String operationId;
  final int retryCount;
  final String status;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final int? lastHttpStatus;

  SyncQueueItem({
    required this.id,
    required this.operation,
    required this.tableName,
    required this.recordId,
    required this.payload,
    required this.operationId,
    required this.retryCount,
    required this.status,
    this.nextAttemptAt,
    this.lastError,
    this.lastHttpStatus,
  });

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id'] as int,
      operation: map['operation'] as String,
      tableName: map['table_name'] as String,
      recordId: map['record_id'] as String,
      payload: map['payload'] as String,
      operationId: (map['operation_id'] as String?) ?? const Uuid().v4(),
      retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
      status: map['status'] as String? ?? 'pending',
      nextAttemptAt: DateTime.tryParse(map['next_attempt_at'] as String? ?? ''),
      lastError: map['last_error'] as String?,
      lastHttpStatus: (map['last_http_status'] as num?)?.toInt(),
    );
  }
}

class SyncQueueSummary {
  final int pending;
  final int retrying;
  final int failedPermanent;
  final Map<String, int> waitingByTable;

  const SyncQueueSummary({
    this.pending = 0,
    this.retrying = 0,
    this.failedPermanent = 0,
    this.waitingByTable = const {},
  });

  int get waiting => pending + retrying;
  bool get isEmpty => waiting == 0 && failedPermanent == 0;
}

class LocalDatabaseService {
  // The encrypted AppDatabase is the only local source of truth. The former
  // secondary `dentalcare_sync.db` queue was unencrypted and account-agnostic.
  static const _patientColumns = {
    'id',
    'name',
    'phone',
    'whatsappOptIn',
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
    final generation =
        expectedGeneration ?? AppDatabase.captureActiveDataGeneration();
    final db = await AppDatabase.database;
    final encryptedPayload = await EncryptionService.encrypt(payload);
    AppDatabase.ensureDataGeneration(generation);
    await db.transaction((txn) async {
      AppDatabase.ensureDataGeneration(generation);
      await ClinicalOutbox.enqueue(txn, {
        'operation': operation,
        'table_name': tableName,
        'record_id': recordId,
        'payload': encryptedPayload,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'retry_count': 0,
        'attempted': 0,
        'status': 'pending',
        'operation_id': const Uuid().v4(),
        'next_attempt_at': null,
        'last_error': null,
        'last_http_status': null,
      });
    });
  }

  static Future<List<SyncQueueItem>> getPendingQueue({
    int limit = 50,
    int? expectedGeneration,
    bool claim = false,
  }) async {
    try {
      final generation =
          expectedGeneration ?? AppDatabase.captureActiveDataGeneration();
      final db = await AppDatabase.database;
      Future<List<SyncQueueItem>> read(DatabaseExecutor executor) async {
        AppDatabase.ensureDataGeneration(generation);
        final now = DateTime.now().toUtc().toIso8601String();
        final rows = await executor.query(
          'sync_queue',
          where:
              "status IN ('pending', 'retrying') AND (next_attempt_at IS NULL OR next_attempt_at <= ?) "
              "AND NOT EXISTS (SELECT 1 FROM sync_queue earlier "
              "WHERE earlier.table_name = sync_queue.table_name "
              "AND earlier.record_id = sync_queue.record_id AND earlier.id < sync_queue.id)",
          whereArgs: [now],
          orderBy: 'created_at ASC, id ASC',
          limit: limit,
        );
        final decrypted = <SyncQueueItem>[];
        for (final storedRow in rows) {
          final row = Map<String, Object?>.from(storedRow);
          try {
            row['payload'] = await EncryptionService.decrypt(
              row['payload'] as String,
            );
            final item = SyncQueueItem.fromMap(Map<String, dynamic>.from(row));
            if (item.tableName == 'appointments' ||
                item.tableName == 'patient_payments') {
              final payload = jsonDecode(item.payload) as Map;
              final patientId = payload['patientId'];
              if (patientId != null &&
                  item.operation != 'delete' &&
                  (await executor.query(
                    'sync_queue',
                    columns: ['id'],
                    where:
                        'table_name = ? AND record_id = ? '
                        "AND (id < ? OR operation = 'insert')",
                    whereArgs: ['patients', patientId, item.id],
                    limit: 1,
                  )).isNotEmpty) {
                continue;
              }
            }
            if (claim) {
              await executor.update(
                'sync_queue',
                {'attempted': 1},
                where: 'id = ?',
                whereArgs: [item.id],
              );
            }
            decrypted.add(item);
          } catch (_) {
            AppDatabase.ensureDataGeneration(generation);
            await executor.update(
              'sync_queue',
              {
                'status': 'failed_permanent',
                'retry_count': 99,
                'last_error': 'The encrypted sync payload could not be read.',
              },
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        }
        AppDatabase.ensureDataGeneration(generation);
        return decrypted;
      }

      return claim ? await db.transaction(read) : await read(db);
    } catch (_) {
      if (claim) rethrow;
      return [];
    }
  }

  static Future<void> markAsCompleted(int id, {int? expectedGeneration}) async {
    final generation =
        expectedGeneration ?? AppDatabase.captureActiveDataGeneration();
    final db = await AppDatabase.database;
    AppDatabase.ensureDataGeneration(generation);
    final deleted = await db.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (deleted != 1) {
      throw StateError('Sync queue item $id was not removed after delivery.');
    }
  }

  /// Ack and the authoritative version advance together. A newer local edit
  /// remains visible; only operations never sent are rebased onto our own ack.
  static Future<void> completePatientOperation(
    SyncQueueItem item,
    Map<String, dynamic> serverRow, {
    required int expectedGeneration,
  }) async {
    await completeClinicalOperation(
      item,
      serverRow,
      expectedGeneration: expectedGeneration,
    );
  }

  static Future<void> completeClinicalOperation(
    SyncQueueItem item,
    Map<String, dynamic> serverRow, {
    required int expectedGeneration,
  }) async {
    if (item.tableName != 'patients' && item.tableName != 'appointments') {
      throw ArgumentError(
        'Only clinical records have version acknowledgements.',
      );
    }
    final db = await AppDatabase.database;
    AppDatabase.ensureDataGeneration(expectedGeneration);
    await db.transaction((txn) async {
      AppDatabase.ensureDataGeneration(expectedGeneration);
      final remaining = await txn.query(
        'sync_queue',
        where: 'table_name = ? AND record_id = ? AND id > ?',
        whereArgs: [item.tableName, item.recordId, item.id],
        orderBy: 'id ASC',
      );
      final version = (serverRow['version'] as num).toInt();
      for (final next in remaining) {
        if ((next['operation'] != 'update' && next['operation'] != 'delete') ||
            next['status'] != 'pending' ||
            next['attempted'] != 0 ||
            (next['retry_count'] as num?) != 0) {
          continue;
        }
        final payload = Map<String, dynamic>.from(
          jsonDecode(await EncryptionService.decrypt(next['payload'] as String))
              as Map,
        );
        payload['version'] = version;
        await txn.update(
          'sync_queue',
          {'payload': await EncryptionService.encrypt(jsonEncode(payload))},
          where: 'id = ?',
          whereArgs: [next['id']],
        );
      }
      final local = await txn.query(
        item.tableName,
        where: 'id = ?',
        whereArgs: [item.recordId],
        limit: 1,
      );
      if (remaining.isEmpty && local.isNotEmpty) {
        await txn.update(
          item.tableName,
          {...serverRow, 'is_synced': 1},
          where: 'id = ?',
          whereArgs: [item.recordId],
        );
      } else {
        await txn.update(
          item.tableName,
          {'version': version},
          where: 'id = ?',
          whereArgs: [item.recordId],
        );
      }
      final deleted = await txn.delete(
        'sync_queue',
        where: 'id = ?',
        whereArgs: [item.id],
      );
      if (deleted != 1) {
        throw StateError('Patient delivery ack was not committed.');
      }
      AppDatabase.ensureDataGeneration(expectedGeneration);
    });
  }

  static Future<DateTime?> scheduleRetry(
    int id, {
    required Duration delay,
    int? httpStatus,
    String? error,
    int? expectedGeneration,
  }) async {
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
      if (rows.isEmpty) return null;
      final nextAttemptAt = DateTime.now().toUtc().add(delay);
      AppDatabase.ensureDataGeneration(generation);
      await db.update(
        'sync_queue',
        {
          'retry_count':
              ((rows.first['retry_count'] as num?)?.toInt() ?? 0) + 1,
          'status': 'retrying',
          'next_attempt_at': nextAttemptAt.toIso8601String(),
          'last_error': error,
          'last_http_status': httpStatus,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return nextAttemptAt;
    } catch (_) {}
    return null;
  }

  static Future<void> markAsPermanentFailure(
    int id, {
    int? httpStatus,
    String? error,
    int? expectedGeneration,
  }) async {
    try {
      final generation =
          expectedGeneration ?? AppDatabase.captureActiveDataGeneration();
      final db = await AppDatabase.database;
      AppDatabase.ensureDataGeneration(generation);
      await db.update(
        'sync_queue',
        {
          'status': 'failed_permanent',
          'next_attempt_at': null,
          'last_error': error,
          'last_http_status': httpStatus,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (_) {}
  }

  static Future<DateTime?> getNextRetryAt({int? expectedGeneration}) async {
    try {
      final generation =
          expectedGeneration ?? AppDatabase.captureActiveDataGeneration();
      final db = await AppDatabase.database;
      final rows = await db.query(
        'sync_queue',
        columns: ['next_attempt_at'],
        where: "status = 'retrying' AND next_attempt_at IS NOT NULL",
        orderBy: 'next_attempt_at ASC',
        limit: 1,
      );
      AppDatabase.ensureDataGeneration(generation);
      if (rows.isEmpty) return null;
      return DateTime.tryParse(rows.first['next_attempt_at'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }

  // ── Sync time ──

  static Future<SyncQueueSummary> getQueueSummary({
    int? expectedGeneration,
  }) async {
    try {
      final generation =
          expectedGeneration ?? AppDatabase.captureActiveDataGeneration();
      final db = await AppDatabase.database;
      final rows = await db.rawQuery(
        'SELECT status, table_name, COUNT(*) AS count FROM sync_queue GROUP BY status, table_name',
      );
      AppDatabase.ensureDataGeneration(generation);
      var pending = 0;
      var retrying = 0;
      var failedPermanent = 0;
      final waitingByTable = <String, int>{};
      for (final row in rows) {
        final count = (row['count'] as num?)?.toInt() ?? 0;
        switch (row['status']) {
          case 'pending':
            pending += count;
            waitingByTable.update(
              row['table_name'] as String,
              (value) => value + count,
              ifAbsent: () => count,
            );
          case 'retrying':
            retrying += count;
            waitingByTable.update(
              row['table_name'] as String,
              (value) => value + count,
              ifAbsent: () => count,
            );
          case 'failed_permanent':
            failedPermanent += count;
        }
      }
      return SyncQueueSummary(
        pending: pending,
        retrying: retrying,
        failedPermanent: failedPermanent,
        waitingByTable: waitingByTable,
      );
    } catch (_) {
      return const SyncQueueSummary();
    }
  }

  static Future<String> getLastSyncTime() async {
    final value = await AppDatabase.getMetadata('last_sync_time');
    final parsed = DateTime.tryParse(value ?? '');
    if (parsed == null || parsed.toUtc().isAfter(DateTime.now().toUtc())) {
      return '1970-01-01T00:00:00.000Z';
    }
    return value!;
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
    data['whatsappOptIn'] = _sqliteBool(data['whatsappOptIn']);
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
