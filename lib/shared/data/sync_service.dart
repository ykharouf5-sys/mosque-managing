import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'api_request_queue.dart';
import 'account_data_lifecycle.dart';
import 'app_database.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'local_database.dart';
import '../../patients/data/patient_api_service.dart';
import '../../patients/data/appointment_api_service.dart';

enum SyncFailureDisposition { retry, discard, resolveConflict, rejectSession }

class SyncService {
  static Timer? _timer;
  static Timer? _reconnectTimer;
  static bool _isSyncing = false;
  static bool _wasOffline = false;
  static bool get isSyncing => _isSyncing;
  static final Set<VoidCallback> _syncCompleteListeners = {};
  static final Set<VoidCallback> _dbReloadListeners = {};

  static void addSyncCompleteListener(VoidCallback listener) =>
      _syncCompleteListeners.add(listener);

  static void removeSyncCompleteListener(VoidCallback listener) =>
      _syncCompleteListeners.remove(listener);

  static void addDbReloadListener(VoidCallback listener) =>
      _dbReloadListeners.add(listener);

  static void removeDbReloadListener(VoidCallback listener) =>
      _dbReloadListeners.remove(listener);

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
    int? generation;
    try {
      generation = AppDatabase.captureActiveDataGeneration();
      await LocalDatabaseService.resetFailedItems(
        expectedGeneration: generation,
      );
      final changed = await _push(generation);
      AppDatabase.ensureDataGeneration(generation);
      final pullResult = await _pull(generation);
      generation = pullResult.generation;
      AppDatabase.ensureDataGeneration(generation);
      _notify(_dbReloadListeners);
      if (changed || pullResult.changed) _notify(_syncCompleteListeners);
    } catch (e) {
      await _handleSyncAuthorizationFailure(e);
      debugPrint('Sync API error: $e');
    } finally {
      _isSyncing = false;
    }
    if (generation != null &&
        AuthService().isLoggedIn &&
        (await LocalDatabaseService.getPendingQueue(
          limit: 1,
          expectedGeneration: generation,
        )).isNotEmpty) {
      Future.delayed(const Duration(seconds: 2), syncNow);
    }
  }

  static Future<void> syncNowWithJitter() async {
    await Future<void>.delayed(Duration(seconds: Random().nextInt(4)));
    await syncNow();
  }

  static void _notify(Set<VoidCallback> listeners) {
    for (final listener in listeners.toList(growable: false)) {
      listener();
    }
  }

  static Future<bool> _push(int generation) async {
    final items = await LocalDatabaseService.getPendingQueue(
      limit: 100,
      expectedGeneration: generation,
    );
    AppDatabase.ensureDataGeneration(generation);
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
            expectedGeneration: generation,
          );
          await LocalDatabaseService.markAsCompleted(
            item.id,
            expectedGeneration: generation,
          );
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
              expectedGeneration: generation,
            );
          } else {
            final row = await AppointmentApiService.update(
              item.recordId,
              payload,
              operationId: item.operationId,
            );
            await AppDatabase.upsertAppointmentFromSync(
              AppointmentApiService.toLocalRow(row),
              expectedGeneration: generation,
            );
          }
          await LocalDatabaseService.markAsCompleted(
            item.id,
            expectedGeneration: generation,
          );
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
            expectedGeneration: generation,
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
            expectedGeneration: generation,
          );
        }
        await LocalDatabaseService.markAsCompleted(
          item.id,
          expectedGeneration: generation,
        );
        changed = true;
      } catch (error) {
        if (error is StaleSessionException ||
            error is StaleAccountDataException) {
          rethrow;
        }
        changed = await _handlePushFailure(item, error, generation) || changed;
        if (!AuthService().isLoggedIn) return changed;
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
          await LocalDatabaseService.markAsCompleted(
            item.id,
            expectedGeneration: generation,
          );
        }
        changed = true;
      } catch (error) {
        if (error is StaleSessionException ||
            error is StaleAccountDataException) {
          rethrow;
        }
        final disposition = classifyFailure(error);
        if (disposition == SyncFailureDisposition.rejectSession) {
          await AuthService().invalidateRejectedSession();
          return changed;
        }
        for (final item in legacy) {
          if (disposition == SyncFailureDisposition.retry) {
            await LocalDatabaseService.markAsFailed(
              item.id,
              expectedGeneration: generation,
            );
          } else {
            await LocalDatabaseService.markAsCompleted(
              item.id,
              expectedGeneration: generation,
            );
          }
        }
      }
    }
    return changed;
  }

  @visibleForTesting
  static SyncFailureDisposition classifyFailure(Object error) {
    if (error is! ApiException) return SyncFailureDisposition.retry;
    if (error.statusCode == 401 || error.statusCode == 419) {
      return SyncFailureDisposition.rejectSession;
    }
    if (error.statusCode == 409) {
      return SyncFailureDisposition.resolveConflict;
    }
    if (error.statusCode == 403 || error.statusCode == 404) {
      return SyncFailureDisposition.discard;
    }
    return SyncFailureDisposition.retry;
  }

  static Future<bool> _handlePushFailure(
    SyncQueueItem item,
    Object error,
    int generation,
  ) async {
    final disposition = classifyFailure(error);
    if (disposition == SyncFailureDisposition.rejectSession) {
      await AuthService().invalidateRejectedSession();
      return true;
    }
    if (item.tableName == 'patient_payments' && error is ApiException) {
      if (error.statusCode == 403 || error.statusCode == 404) {
        final payload = Map<String, dynamic>.from(
          jsonDecode(item.payload) as Map,
        );
        await LocalDatabaseService.markAsCompleted(
          item.id,
          expectedGeneration: generation,
        );
        await AppDatabase.discardLocalRecord(
          'patients',
          payload['patientId'].toString(),
          expectedGeneration: generation,
        );
        return true;
      }
      if (error.statusCode == 409 || error.statusCode == 422) {
        return _reconcileRejectedPayment(item, generation);
      }
    }
    if (disposition == SyncFailureDisposition.retry) {
      await LocalDatabaseService.markAsFailed(
        item.id,
        expectedGeneration: generation,
      );
      return false;
    }

    if (disposition == SyncFailureDisposition.resolveConflict &&
        error is ApiException) {
      final current = _conflictRecord(error, item.tableName);
      if (current != null) {
        if (item.tableName == 'patients') {
          await AppDatabase.upsertPatientFromSync(
            PatientApiService.toLocalRow(current),
            force: true,
            expectedGeneration: generation,
          );
        } else if (item.tableName == 'appointments') {
          await AppDatabase.upsertAppointmentFromSync(
            AppointmentApiService.toLocalRow(current),
            force: true,
            expectedGeneration: generation,
          );
        }
        await LocalDatabaseService.markAsCompleted(
          item.id,
          expectedGeneration: generation,
        );
        return true;
      }
    }

    await LocalDatabaseService.markAsCompleted(
      item.id,
      expectedGeneration: generation,
    );
    if (item.tableName == 'patients' || item.tableName == 'appointments') {
      await AppDatabase.discardLocalRecord(
        item.tableName,
        item.recordId,
        expectedGeneration: generation,
      );
      return true;
    }
    return false;
  }

  static Future<bool> _reconcileRejectedPayment(
    SyncQueueItem item,
    int generation,
  ) async {
    final payload = Map<String, dynamic>.from(jsonDecode(item.payload) as Map);
    final patientId = payload['patientId']?.toString();
    if (patientId == null || patientId.isEmpty) {
      await LocalDatabaseService.markAsCompleted(
        item.id,
        expectedGeneration: generation,
      );
      return false;
    }
    try {
      final response = await ApiClient.instance.get('/patients/$patientId');
      final current = Map<String, dynamic>.from(response.data['data'] as Map);
      await AppDatabase.upsertPatientFromSync(
        PatientApiService.toLocalRow(current),
        force: true,
        expectedGeneration: generation,
      );
      await LocalDatabaseService.markAsCompleted(
        item.id,
        expectedGeneration: generation,
      );
      return true;
    } catch (error) {
      if (error is StaleSessionException ||
          error is StaleAccountDataException) {
        rethrow;
      }
      if (error is ApiException &&
          (error.statusCode == 403 || error.statusCode == 404)) {
        await LocalDatabaseService.markAsCompleted(
          item.id,
          expectedGeneration: generation,
        );
        await AppDatabase.discardLocalRecord(
          'patients',
          patientId,
          expectedGeneration: generation,
        );
        return true;
      }
      await LocalDatabaseService.markAsFailed(
        item.id,
        expectedGeneration: generation,
      );
      return false;
    }
  }

  static Future<void> _handleSyncAuthorizationFailure(Object error) async {
    if (error is! ApiException) return;
    if (error.statusCode == 401 || error.statusCode == 419) {
      await AuthService().invalidateRejectedSession();
      return;
    }
    if (error.statusCode == 403) {
      try {
        await AuthService().refreshCurrentUser();
      } catch (_) {
        // A network error while refreshing must not destroy a valid offline
        // session; rejected tokens are purged by refreshCurrentUser itself.
      }
    }
  }

  static Map<String, dynamic>? _conflictRecord(
    ApiException error,
    String tableName,
  ) {
    final body = error.details;
    if (body is! Map) return null;
    final data = body['data'];
    if (data is! Map) return null;
    final key = tableName == 'patients'
        ? 'current_patient'
        : tableName == 'appointments'
        ? 'current_appointment'
        : null;
    if (key == null || data[key] is! Map) return null;
    return Map<String, dynamic>.from(data[key] as Map);
  }

  static Future<({bool changed, int generation})> _pull(
    int initialGeneration,
  ) async {
    var generation = initialGeneration;
    AppDatabase.ensureDataGeneration(generation);
    var since = await LocalDatabaseService.getLastSyncTime();
    AppDatabase.ensureDataGeneration(generation);
    String? cursor;
    var changed = false;
    String? serverTime;
    var scopeVersion =
        AppDatabase.activeClinicalScopeVersion ??
        AuthService().clinicalScopeVersion;
    if (scopeVersion < 1) {
      throw StateError('Cannot sync without an active clinical scope.');
    }
    do {
      final r = await ApiClient.instance.get(
        '/sync/pull',
        query: {
          'since': since,
          'limit': '25',
          'scope_version': '$scopeVersion',
          'cursor': ?cursor,
        },
      );
      final data = Map<String, dynamic>.from(r.data['data'] as Map);
      final returnedScope = (data['scope_version'] as num?)?.toInt() ?? 0;
      if (returnedScope < 1) {
        throw StateError('The server returned an invalid clinical scope.');
      }
      final serverRequestedReset = data['reset_required'] == true;
      final resetRequired =
          serverRequestedReset || returnedScope != scopeVersion;
      if (resetRequired) {
        await _activateServerScope(
          returnedScope,
          forceReset: serverRequestedReset,
        );
        generation = AppDatabase.captureActiveDataGeneration();
        scopeVersion = returnedScope;
        since = '1970-01-01T00:00:00.000Z';
        changed = true;
      }
      for (final row in data['patients'] as List? ?? const []) {
        await LocalDatabaseService.upsertPatientFromSync(
          Map<String, dynamic>.from(row as Map),
          expectedGeneration: generation,
        );
        changed = true;
      }
      for (final row in data['appointments'] as List? ?? const []) {
        await LocalDatabaseService.upsertAppointmentFromSync(
          Map<String, dynamic>.from(row as Map),
          expectedGeneration: generation,
        );
        changed = true;
      }
      cursor = data['next_cursor']?.toString();
      serverTime = data['server_time']?.toString();
    } while (cursor != null);
    if (serverTime != null) {
      await LocalDatabaseService.setLastSyncTime(
        serverTime,
        expectedGeneration: generation,
      );
    }
    return (changed: changed, generation: generation);
  }

  static Future<void> _activateServerScope(
    int scopeVersion, {
    required bool forceReset,
  }) async {
    final accountId = AuthService().userId;
    if (accountId == null || accountId.isEmpty) {
      throw StateError('Cannot activate a clinical scope without an account.');
    }
    await AccountDataLifecycle.activate(
      accountId: accountId,
      clinicalScopeVersion: scopeVersion,
      forceClinicalReset: forceReset,
    );
  }

  static void dispose() {
    _timer?.cancel();
    _reconnectTimer?.cancel();
    ConnectivityService.isOnline.removeListener(_onConnectivityChanged);
    _syncCompleteListeners.clear();
    _dbReloadListeners.clear();
  }
}
