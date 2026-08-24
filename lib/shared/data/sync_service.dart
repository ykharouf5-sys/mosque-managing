import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'app_database.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'local_database.dart';
import '../../patients/data/patient_api_service.dart';
import '../../patients/data/appointment_api_service.dart';

class SyncService {
  static Timer? _timer;
  static Timer? _reconnectTimer;
  static bool _isSyncing = false;
  static bool _wasOffline = false;
  static bool get isSyncing => _isSyncing;
  static VoidCallback? onSyncComplete;
  static VoidCallback? onDbReload;
  static Future<void> init() async {
    ConnectivityService.isOnline.addListener(_onConnectivityChanged);
    _timer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (ConnectivityService.isOnline.value) syncNow();
    });
    if (ConnectivityService.isOnline.value) {
      Future.delayed(Duration(seconds: Random().nextInt(120)), syncNow);
    }
  }

  static void _onConnectivityChanged() {
    final online = ConnectivityService.isOnline.value;
    if (online && _wasOffline) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(seconds: Random().nextInt(30)), syncNow);
    }
    _wasOffline = !online;
  }

  static Future<void> syncNow() async {
    if (_isSyncing ||
        !ConnectivityService.isOnline.value ||
        !AuthService().hasPermission('sync.use')) {
      return;
    }
    _isSyncing = true;
    try {
      final changed = await _push();
      final pulled = await _pull();
      onDbReload?.call();
      if (changed || pulled) onSyncComplete?.call();
    } catch (e) {
      debugPrint('Sync API error: $e');
    } finally {
      _isSyncing = false;
    }
    if ((await LocalDatabaseService.getPendingQueue(limit: 1)).isNotEmpty) {
      Future.delayed(const Duration(seconds: 2), syncNow);
    }
  }

  static Future<void> syncNowWithJitter() async {
    await Future<void>.delayed(Duration(seconds: Random().nextInt(4)));
    await syncNow();
  }

  static Future<bool> _push() async {
    final items = await LocalDatabaseService.getPendingQueue(limit: 100);
    if (items.isEmpty) return false;
    var changed = false;
    final legacy = [];
    for (final item in items) {
      if (item.tableName != 'patients' &&
          item.tableName != 'appointments' &&
          item.tableName != 'patient_payments') {
        legacy.add(item);
        continue;
      }
      try {
        final payload = Map<String, dynamic>.from(
          jsonDecode(item.payload) as Map,
        );
        if (item.tableName == 'patient_payments') {
          final response = await ApiClient.instance.post(
            '/patients/${payload['patientId']}/payments',
            body: {
              'id': item.recordId,
              'amount': payload['amount'],
              'method': payload['method'] ?? 'cash',
              'note': payload['note'],
              'paid_at': payload['paidAt'],
            },
          );
          final patient = Map<String, dynamic>.from(
            response.data['data']['patient'] as Map,
          );
          await AppDatabase.applyServerPaymentSummary(
            patient['id'].toString(),
            amountPaid: (patient['amountPaid'] as num).toDouble(),
            todayPayment: (patient['todayPayment'] as num).toDouble(),
            version: (patient['version'] as num).toInt(),
          );
          await LocalDatabaseService.markAsCompleted(item.id);
          changed = true;
          continue;
        }
        if (item.tableName == 'appointments') {
          if (item.operation == 'delete') {
            await AppointmentApiService.delete(
              item.recordId,
              operationId: item.operationId,
            );
          } else if (item.operation == 'insert') {
            final row = await AppointmentApiService.create(
              payload,
              operationId: item.operationId,
            );
            await AppDatabase.upsertAppointmentFromSync(
              AppointmentApiService.toLocalRow(row),
            );
          } else {
            final row = await AppointmentApiService.update(
              item.recordId,
              payload,
              operationId: item.operationId,
            );
            await AppDatabase.upsertAppointmentFromSync(
              AppointmentApiService.toLocalRow(row),
            );
          }
          await LocalDatabaseService.markAsCompleted(item.id);
          changed = true;
          continue;
        }
        final data = Map<String, dynamic>.from(payload)
          ..removeWhere(
            (key, _) => const {
              'id',
              'clinic_id',
              'created_at',
              'updated_at',
              'deleted_at',
              'is_synced',
              'device_id',
              'version',
            }.contains(key),
          );
        if (item.operation == 'delete') {
          await ApiClient.instance.delete(
            '/patients/${item.recordId}',
            headers: {'Idempotency-Key': item.operationId},
          );
        } else if (item.operation == 'insert') {
          final response = await ApiClient.instance.post(
            '/patients',
            headers: {'Idempotency-Key': item.operationId},
            body: {
              'id': item.recordId,
              'device_id': payload['device_id'],
              'data': data,
            },
          );
          await AppDatabase.upsertPatientFromSync(
            PatientApiService.toLocalRow(
              Map<String, dynamic>.from(response.data['data'] as Map),
            ),
          );
        } else {
          final response = await ApiClient.instance.put(
            '/patients/${item.recordId}',
            headers: {'Idempotency-Key': item.operationId},
            body: {
              'version': payload['version'] ?? 1,
              'device_id': payload['device_id'],
              'data': data,
            },
          );
          await AppDatabase.upsertPatientFromSync(
            PatientApiService.toLocalRow(
              Map<String, dynamic>.from(response.data['data'] as Map),
            ),
          );
        }
        await LocalDatabaseService.markAsCompleted(item.id);
        changed = true;
      } catch (_) {
        await LocalDatabaseService.markAsFailed(item.id);
      }
    }
    if (legacy.isNotEmpty) {
      try {
        await ApiClient.instance.post(
          '/sync/push',
          body: {
            'operations': legacy
                .map(
                  (i) => {
                    'operation_id': i.operationId,
                    'id': i.recordId,
                    'table': i.tableName,
                    'operation': i.operation,
                    'payload': jsonDecode(i.payload),
                  },
                )
                .toList(),
          },
        );
        for (final item in legacy) {
          await LocalDatabaseService.markAsCompleted(item.id);
        }
        changed = true;
      } catch (_) {
        for (final item in legacy) {
          await LocalDatabaseService.markAsFailed(item.id);
        }
      }
    }
    return changed;
  }

  static Future<bool> _pull() async {
    final since = await LocalDatabaseService.getLastSyncTime();
    String? cursor = '0';
    var changed = false;
    String? serverTime;
    do {
      final r = await ApiClient.instance.get(
        '/sync/pull',
        query: {'since': since, 'cursor': cursor!, 'limit': '25'},
      );
      final data = Map<String, dynamic>.from(r.data['data']);
      for (final row in data['patients'] as List) {
        await LocalDatabaseService.upsertPatientFromSync(
          Map<String, dynamic>.from(row),
        );
        changed = true;
      }
      for (final row in data['appointments'] as List) {
        await LocalDatabaseService.upsertAppointmentFromSync(
          Map<String, dynamic>.from(row),
        );
        changed = true;
      }
      cursor = data['next_cursor']?.toString();
      serverTime = data['server_time']?.toString();
    } while (cursor != null);
    if (serverTime != null) {
      await LocalDatabaseService.setLastSyncTime(serverTime);
    }
    return changed;
  }

  static void dispose() {
    _timer?.cancel();
    _reconnectTimer?.cancel();
    ConnectivityService.isOnline.removeListener(_onConnectivityChanged);
  }
}
