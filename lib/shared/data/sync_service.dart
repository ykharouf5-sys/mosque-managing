import 'dart:async';
import 'dart:convert';
import 'sync_payload.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'api_request_queue.dart';
import 'clinical_sync_policy.dart';
import 'clinical_delta_pull.dart';
import 'clinical_sync_coordinator.dart';
import 'app_database.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'local_database.dart';
import 'sync_backoff.dart';
import '../../patients/data/patient_api_service.dart';
import '../../patients/data/appointment_api_service.dart';

enum SyncFailureDisposition {
  retry,
  permanentFailure,
  discard,
  resolveConflict,
  rejectSession,
}

typedef AsyncSyncListener = Future<void> Function();

class _ClinicalSyncRun extends ClinicalSyncFlight {
  _ClinicalSyncRun({
    required super.key,
    required this.generation,
    required this.session,
    required this.headers,
    required this.windowDate,
    required super.pullRequested,
  });
  final int generation;
  final int session;
  final Map<String, String> headers;
  final DateTime windowDate;

  void ensureCurrent() {
    if (AuthService().sessionGeneration != session) {
      throw const StaleSessionException();
    }
    AppDatabase.ensureDataGeneration(generation);
  }
}

class SyncStatusSnapshot {
  final int waiting;
  final int failedPermanent;
  final bool isSyncing;
  final Map<String, int> waitingByTable;
  final String? pullError;
  final int recoverySnapshots;

  const SyncStatusSnapshot({
    this.waiting = 0,
    this.failedPermanent = 0,
    this.isSyncing = false,
    this.waitingByTable = const {},
    this.pullError,
    this.recoverySnapshots = 0,
  });
}

class SyncService {
  static Timer? _reconnectTimer;
  static Timer? _writeDebounceTimer;
  static Timer? _retryTimer;
  static DateTime? _retryDueAt;
  static Completer<void>? _writeDebounceCompleter;
  static final _flights = ClinicalSyncCoordinator<_ClinicalSyncRun>(
    _pullPolicy,
  );
  static String? _contextKey;
  static final _pullPolicy = ClinicalSyncPolicy();
  static bool _wasOffline = false;
  static bool _isAppActive = true;
  static bool _initialized = false;
  static int _pullRetryCount = 0;
  static DateTime? _pullRetryDueAt;
  static String? _lastPullError;
  static bool _deferredPull = false;
  static bool get isSyncing => _flights.active != null;
  static final Random _random = Random();
  static final Set<AsyncSyncListener> _syncCompleteListeners = {};
  static final Set<AsyncSyncListener> _dbReloadListeners = {};
  static final ValueNotifier<SyncStatusSnapshot> status = ValueNotifier(
    const SyncStatusSnapshot(),
  );

  static void addSyncCompleteListener(AsyncSyncListener listener) =>
      _syncCompleteListeners.add(listener);

  static void removeSyncCompleteListener(AsyncSyncListener listener) =>
      _syncCompleteListeners.remove(listener);

  static void addDbReloadListener(AsyncSyncListener listener) =>
      _dbReloadListeners.add(listener);

  static void removeDbReloadListener(AsyncSyncListener listener) =>
      _dbReloadListeners.remove(listener);

  static Future<void> init() async {
    _initialized = true;
    _wasOffline = !ConnectivityService.isOnline.value;
    ConnectivityService.isOnline.removeListener(_onConnectivityChanged);
    ConnectivityService.isOnline.addListener(_onConnectivityChanged);
    await refreshStatus();
    if (ConnectivityService.isOnline.value) {
      // Resume the active account's cloud synchronization immediately after
      // restoring a session. Write-triggered retries still use jitter below.
      Future<void>.microtask(() async {
        await syncNow();
      });
    }
  }

  static void _onConnectivityChanged() {
    final online = ConnectivityService.isOnline.value;
    if (online && _wasOffline) {
      _reconnectTimer?.cancel();
      final generation = AppDatabase.dataGeneration;
      final session = AuthService().sessionGeneration;
      _reconnectTimer = Timer(Duration(seconds: Random().nextInt(10)), () {
        if (generation != AppDatabase.dataGeneration ||
            session != AuthService().sessionGeneration) {
          return;
        }
        syncNow();
      });
    } else if (!online) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _retryDueAt = null;
    }
    _wasOffline = !online;
  }

  static void setAppActive(bool active) {
    if (_isAppActive == active) return;
    _isAppActive = active;
    if (!active) {
      _reconnectTimer?.cancel();
      _retryTimer?.cancel();
      _retryTimer = null;
      _retryDueAt = null;
      return;
    }
    if (active && ConnectivityService.isOnline.value) {
      _reconnectTimer?.cancel();
      final generation = AppDatabase.dataGeneration;
      final session = AuthService().sessionGeneration;
      _reconnectTimer = Timer(
        Duration(milliseconds: _random.nextInt(3001)),
        () {
          if (generation == AppDatabase.dataGeneration &&
              session == AuthService().sessionGeneration) {
            syncNow();
          }
        },
      );
    }
  }

  static Future<bool> syncNow({
    bool force = false,
    bool pullChanges = true,
    bool manual = false,
  }) {
    if (!_isAppActive ||
        !ConnectivityService.isOnline.value ||
        !AuthService().hasPermission('sync.use')) {
      return Future.value(false);
    }
    final auth = AuthService();
    if (auth.userId == null || auth.userId != AppDatabase.activeAccountId) {
      return Future.value(false);
    }
    final generation = AppDatabase.captureActiveDataGeneration();
    final today = DateTime.now();
    final key = jsonEncode([
      auth.userId,
      auth.clinicId,
      AppDatabase.activeClinicalScopeVersion,
      auth.sessionGeneration,
      generation,
      'clinical',
      today.year,
      today.month,
      today.day,
    ]);
    if (_contextKey != key) {
      _contextKey = key;
      _pullPolicy.bind(key);
      _pullRetryCount = 0;
      _pullRetryDueAt = null;
      _lastPullError = null;
      _deferredPull = false;
      _retryTimer?.cancel();
      _retryTimer = null;
      _retryDueAt = null;
    }
    return _flights.request(
      key: key,
      pullChanges: pullChanges,
      force: force,
      manual: manual,
      create: (pull) => _ClinicalSyncRun(
        key: key,
        generation: generation,
        windowDate: today,
        session: auth.sessionGeneration,
        headers: Map.unmodifiable({
          'X-Clinical-Clinic': auth.clinicId ?? '',
          'X-Clinical-Scope-Version':
              '${AppDatabase.activeClinicalScopeVersion ?? auth.clinicalScopeVersion}',
        }),
        pullRequested: pull,
      ),
      execute: (flight) {
        status.value = SyncStatusSnapshot(
          waiting: status.value.waiting,
          failedPermanent: status.value.failedPermanent,
          isSyncing: true,
          waitingByTable: status.value.waitingByTable,
          pullError: _lastPullError,
          recoverySnapshots: status.value.recoverySnapshots,
        );
        return _runSync(flight);
      },
      onFinished: (flight) async {
        if (_contextKey == key) await refreshStatus();
      },
    );
  }

  static Future<bool> _runSync(_ClinicalSyncRun run) async {
    final generation = run.generation;
    var dataChanged = false;
    try {
      run.ensureCurrent();
      final pushResult = await _push(run);
      run.ensureCurrent();
      dataChanged = pushResult.changed;
      if (!pushResult.serverAvailable && run.pullRequested) {
        _deferredPull = true;
      }
      if (pushResult.serverAvailable && run.pullRequested) {
        run.pullRequested = false;
        run.pulling = true;
        final pullResult = await _pull(run);
        run.ensureCurrent();
        dataChanged = dataChanged || pullResult.changed;
        _pullRetryCount = 0;
        _pullRetryDueAt = null;
        _pullPolicy.succeeded(run.key);
        _lastPullError = null;
        _deferredPull = false;
      }
      if (dataChanged) {
        await _notify(_dbReloadListeners);
        await _notify(_syncCompleteListeners);
      }
    } catch (e) {
      if (e is StaleSessionException || e is StaleAccountDataException) {
        return false;
      }
      try {
        run.ensureCurrent();
      } catch (_) {
        return false;
      }
      _lastPullError = _errorMessage(e);
      await _handleSyncAuthorizationFailure(e);
      try {
        run.ensureCurrent();
      } catch (_) {
        return false;
      }
      if (_isRetryableFailure(e)) _scheduleTransientRetry(e);
    }
    try {
      run.ensureCurrent();
    } catch (_) {
      return false;
    }
    if (AuthService().isLoggedIn &&
        (await LocalDatabaseService.getPendingQueue(
          limit: 1,
          expectedGeneration: generation,
        )).isNotEmpty) {
      Timer(Duration(seconds: 2 + _random.nextInt(4)), () {
        try {
          run.ensureCurrent();
        } catch (_) {
          return;
        }
        syncNow(force: true, pullChanges: false);
      });
    }
    if (AuthService().isLoggedIn) {
      await _scheduleStoredRetry(generation);
      if (_pullRetryDueAt != null) _scheduleRetryAt(_pullRetryDueAt!);
      if (_deferredPull && _pullPolicy.blockedUntil != null) {
        _scheduleRetryAt(_pullPolicy.blockedUntil!);
      }
    }
    return dataChanged;
  }

  static Future<void> syncNowWithJitter() {
    final generation = AppDatabase.captureActiveDataGeneration();
    final session = AuthService().sessionGeneration;
    unawaited(refreshStatus());
    _writeDebounceTimer?.cancel();
    final completer = _writeDebounceCompleter ??= Completer<void>();
    _writeDebounceTimer = Timer(
      Duration(milliseconds: 700 + _random.nextInt(801)),
      () async {
        _writeDebounceTimer = null;
        try {
          if (session != AuthService().sessionGeneration) {
            throw const StaleSessionException();
          }
          AppDatabase.ensureDataGeneration(generation);
          await syncNow(force: true, pullChanges: false);
          if (!completer.isCompleted) completer.complete();
        } on StaleSessionException {
          if (!completer.isCompleted) completer.complete();
        } on StaleAccountDataException {
          if (!completer.isCompleted) completer.complete();
        } catch (error, stack) {
          if (!completer.isCompleted) completer.completeError(error, stack);
        } finally {
          if (identical(_writeDebounceCompleter, completer)) {
            _writeDebounceCompleter = null;
          }
        }
      },
    );
    return completer.future;
  }

  static Future<void> _notify(Set<AsyncSyncListener> listeners) async {
    await Future.wait(
      listeners.toList(growable: false).map((listener) => listener()),
    );
  }

  static Future<void> refreshStatus() async {
    final generation = AppDatabase.dataGeneration;
    final session = AuthService().sessionGeneration;
    final summary = await LocalDatabaseService.getQueueSummary();
    final recoverySnapshots =
        await AppDatabase.getClinicalRecoverySnapshotCount();
    if (generation != AppDatabase.dataGeneration ||
        session != AuthService().sessionGeneration) {
      return;
    }
    status.value = SyncStatusSnapshot(
      waiting: summary.waiting,
      failedPermanent: summary.failedPermanent,
      isSyncing: isSyncing,
      waitingByTable: summary.waitingByTable,
      pullError: _lastPullError,
      recoverySnapshots: recoverySnapshots,
    );
  }

  static Future<({bool changed, bool serverAvailable})> _push(
    _ClinicalSyncRun run,
  ) async {
    final generation = run.generation;
    var items = await LocalDatabaseService.getPendingQueue(
      limit: 25,
      expectedGeneration: generation,
      claim: true,
    );
    AppDatabase.ensureDataGeneration(generation);
    if (items.isEmpty) return (changed: false, serverAvailable: true);
    final unsafeDeletes = items
        .where(
          (item) =>
              item.operation == 'delete' &&
              (item.tableName == 'patients' ||
                  item.tableName == 'appointments') &&
              decodeSyncPayload(item.payload)['version'] is! num,
        )
        .toList();
    for (final item in unsafeDeletes) {
      run.ensureCurrent();
      await LocalDatabaseService.markAsPermanentFailure(
        item.id,
        error: 'Legacy delete has no base version; retained for review.',
        expectedGeneration: generation,
      );
    }
    items = items.where((item) => !unsafeDeletes.contains(item)).toList();
    var changed = false;
    var serverAvailable = true;

    final canBatch = canBatchClinicalOperations(
      items.map(
        (item) => (tableName: item.tableName, operation: item.operation),
      ),
    );
    final clinicalItems = items
        .where(
          (item) =>
              canBatch &&
              (item.tableName == 'patients' ||
                  item.tableName == 'appointments'),
        )
        .toList(growable: false);
    if (clinicalItems.isNotEmpty) {
      try {
        run.ensureCurrent();
        final response = await ApiClient.instance.post(
          '/sync/push',
          headers: run.headers,
          maxRetries: 0,
          body: {
            'operations': clinicalItems
                .map(
                  (item) => {
                    'operation_id': item.operationId,
                    'id': item.recordId,
                    'table': item.tableName,
                    'operation': item.operation,
                    'payload': decodeSyncPayload(item.payload),
                  },
                )
                .toList(growable: false),
          },
        );
        final results = {
          for (final result in response.data['data']['results'] as List)
            result['id']: result,
        };
        run.ensureCurrent();
        if (clinicalItems.any(
          (item) => results[item.recordId]?['status'] != 'accepted',
        )) {
          throw StateError('Missing clinical operation acknowledgement.');
        }
        final completedIds = clinicalItems.map((item) => item.id).toSet();
        for (final item in clinicalItems) {
          final result = results[item.recordId];
          if (item.operation != 'delete') {
            await LocalDatabaseService.completeClinicalOperation(item, {
              'version': clinicalAcknowledgedVersion(
                operation: item.operation,
                payload: decodeSyncPayload(item.payload),
                receipt: Map<String, dynamic>.from(result as Map),
              ),
              if (result['updated_at'] != null)
                'updated_at': result['updated_at'],
            }, expectedGeneration: generation);
          } else {
            // A delete receipt does not overwrite a live local record.
            await LocalDatabaseService.markAsCompleted(
              item.id,
              expectedGeneration: generation,
            );
          }
        }
        items = items
            .where((item) => !completedIds.contains(item.id))
            .toList(growable: false);
        changed = true;
      } catch (error) {
        run.ensureCurrent();
        await _checkChangedClinicalScope(error, run);
        if (error is StaleSessionException ||
            error is StaleAccountDataException) {
          rethrow;
        }
        final disposition = classifyFailure(error);
        if (disposition == SyncFailureDisposition.rejectSession) {
          await AuthService().invalidateRejectedSession();
          return (changed: changed, serverAvailable: false);
        }
        if (disposition == SyncFailureDisposition.retry) {
          for (final item in clinicalItems) {
            await _defer(item, error, generation);
          }
          return (changed: changed, serverAvailable: false);
        }
        // A single conflict aborts the atomic batch. Fall back to the
        // per-record path below so the valid operations can still progress.
      }
    }
    if (items.isEmpty) {
      return (changed: changed, serverAvailable: serverAvailable);
    }
    final legacy = [];
    for (var itemIndex = 0; itemIndex < items.length; itemIndex++) {
      final item = items[itemIndex];
      if (item.tableName != 'patients' &&
          item.tableName != 'appointments' &&
          item.tableName != 'patient_payments') {
        legacy.add(item);
        continue;
      }
      try {
        run.ensureCurrent();
        final payload = decodeSyncPayload(item.payload);
        if (item.operation == 'delete' && payload['version'] is! num) {
          await LocalDatabaseService.markAsPermanentFailure(
            item.id,
            error: 'Legacy delete has no base version; retained for review.',
            expectedGeneration: generation,
          );
          continue;
        }
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
              clinicalHeaders: run.headers,
              version: (payload['version'] as num?)?.toInt(),
            );
          } else if (item.operation == 'insert') {
            final row = await AppointmentApiService.create(
              payload,
              operationId: item.operationId,
              clinicalHeaders: run.headers,
            );
            await LocalDatabaseService.completeClinicalOperation(
              item,
              AppointmentApiService.toLocalRow(row),
              expectedGeneration: generation,
            );
          } else {
            final row = await AppointmentApiService.update(
              item.recordId,
              payload,
              operationId: item.operationId,
              clinicalHeaders: run.headers,
            );
            await LocalDatabaseService.completeClinicalOperation(
              item,
              AppointmentApiService.toLocalRow(row),
              expectedGeneration: generation,
            );
          }
          if (item.operation == 'delete') {
            await LocalDatabaseService.markAsCompleted(
              item.id,
              expectedGeneration: generation,
            );
          }
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
            headers: {...run.headers, 'Idempotency-Key': item.operationId},
            body: {'version': payload['version']},
          );
        } else if (item.operation == 'insert') {
          final response = await ApiClient.instance.post(
            '/patients',
            headers: {...run.headers, 'Idempotency-Key': item.operationId},
            body: {
              'id': item.recordId,
              'device_id': payload['device_id'],
              'data': data,
            },
          );
          await LocalDatabaseService.completePatientOperation(
            item,
            PatientApiService.toLocalRow(
              Map<String, dynamic>.from(response.data['data'] as Map),
            ),
            expectedGeneration: generation,
          );
        } else {
          final response = await ApiClient.instance.put(
            '/patients/${item.recordId}',
            headers: {...run.headers, 'Idempotency-Key': item.operationId},
            body: {
              'version': payload['version'] ?? 1,
              'device_id': payload['device_id'],
              'data': data,
            },
          );
          await LocalDatabaseService.completePatientOperation(
            item,
            PatientApiService.toLocalRow(
              Map<String, dynamic>.from(response.data['data'] as Map),
            ),
            expectedGeneration: generation,
          );
        }
        if (item.tableName != 'patients' || item.operation == 'delete') {
          await LocalDatabaseService.markAsCompleted(
            item.id,
            expectedGeneration: generation,
          );
        }
        changed = true;
      } catch (error) {
        run.ensureCurrent();
        await _checkChangedClinicalScope(error, run);
        if (error is StaleSessionException ||
            error is StaleAccountDataException) {
          rethrow;
        }
        final disposition = classifyFailure(error);
        changed = await _handlePushFailure(item, error, generation) || changed;
        if (disposition == SyncFailureDisposition.retry) {
          serverAvailable = false;
          for (final remaining in items.skip(itemIndex + 1)) {
            await _defer(remaining, error, generation);
          }
          break;
        }
        if (!AuthService().isLoggedIn) {
          return (changed: changed, serverAvailable: false);
        }
      }
    }
    if (!serverAvailable) {
      for (final item in legacy) {
        await _defer(
          item,
          const ApiException(503, 'Synchronization is temporarily delayed.'),
          generation,
        );
      }
      return (changed: changed, serverAvailable: false);
    }
    if (legacy.isNotEmpty) {
      try {
        run.ensureCurrent();
        await ApiClient.instance.post(
          '/sync/push',
          headers: run.headers,
          body: {
            'operations': legacy
                .map(
                  (i) => {
                    'operation_id': i.operationId,
                    'id': i.recordId,
                    'table': i.tableName,
                    'operation': i.operation,
                    'payload': decodeSyncPayload(i.payload),
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
        run.ensureCurrent();
        await _checkChangedClinicalScope(error, run);
        if (error is StaleSessionException ||
            error is StaleAccountDataException) {
          rethrow;
        }
        final disposition = classifyFailure(error);
        if (disposition == SyncFailureDisposition.rejectSession) {
          await AuthService().invalidateRejectedSession();
          return (changed: changed, serverAvailable: false);
        }
        for (final item in legacy) {
          if (disposition == SyncFailureDisposition.retry) {
            serverAvailable = false;
            await _defer(item, error, generation);
          } else if (disposition == SyncFailureDisposition.permanentFailure) {
            await LocalDatabaseService.markAsPermanentFailure(
              item.id,
              httpStatus: error is ApiException ? error.statusCode : null,
              error: _errorMessage(error),
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
    return (changed: changed, serverAvailable: serverAvailable);
  }

  static Future<void> _checkChangedClinicalScope(
    Object error,
    _ClinicalSyncRun run,
  ) async {
    if (error is! ApiException ||
        error.statusCode != 403 ||
        error.details is! Map ||
        (error.details as Map)['code'] != 'clinical_scope_changed') {
      return;
    }
    run.ensureCurrent();
    try {
      await AuthService().refreshCurrentUser();
    } on StaleSessionException {
      rethrow;
    } on StaleAccountDataException {
      rethrow;
    } catch (_) {
      // The immutable operation stays queued; a failed profile refresh must
      // never make it eligible for the server's new clinic.
    }
    run.ensureCurrent();
    throw const ApiException(503, 'Clinical scope refresh is required.');
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
    if (error.statusCode == 400 ||
        error.statusCode == 413 ||
        error.statusCode == 422) {
      return SyncFailureDisposition.permanentFailure;
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
    if (kDebugMode) {
      debugPrint(
        '[Sync] ${item.tableName}/${item.operation} failed: '
        '${error is ApiException ? error.statusCode : error.runtimeType} '
        '${_errorMessage(error)}',
      );
    }
    final disposition = classifyFailure(error);
    if (disposition == SyncFailureDisposition.rejectSession) {
      await AuthService().invalidateRejectedSession();
      return true;
    }
    if ((item.tableName == 'patients' || item.tableName == 'appointments') &&
        error is ApiException &&
        (error.statusCode == 403 || error.statusCode == 404)) {
      await LocalDatabaseService.markAsPermanentFailure(
        item.id,
        httpStatus: error.statusCode,
        error:
            'Clinical record unavailable; local operation retained for review.',
        expectedGeneration: generation,
      );
      AppDatabase.ensureDataGeneration(generation);
      await AuthService().refreshCurrentUser();
      return false;
    }
    if (item.tableName == 'patient_payments' && error is ApiException) {
      if (error.statusCode == 403 || error.statusCode == 404) {
        final payload = decodeSyncPayload(item.payload);
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
      await _defer(item, error, generation);
      return false;
    }
    if (disposition == SyncFailureDisposition.permanentFailure) {
      await LocalDatabaseService.markAsPermanentFailure(
        item.id,
        httpStatus: error is ApiException ? error.statusCode : null,
        error: _errorMessage(error),
        expectedGeneration: generation,
      );
      return false;
    }

    if (disposition == SyncFailureDisposition.resolveConflict &&
        error is ApiException) {
      if (item.tableName == 'patients' || item.tableName == 'appointments') {
        await LocalDatabaseService.markAsPermanentFailure(
          item.id,
          httpStatus: error.statusCode,
          error:
              'Clinical record changed on another device; local operation retained for review.',
          expectedGeneration: generation,
        );
        return false;
      }
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
      await LocalDatabaseService.markAsPermanentFailure(
        item.id,
        httpStatus: error.statusCode,
        error: _errorMessage(error),
        expectedGeneration: generation,
      );
      return false;
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
      await _defer(item, error, generation);
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

  static Future<void> _defer(
    SyncQueueItem item,
    Object error,
    int generation,
  ) async {
    final retryAfter = error is ApiException ? error.retryAfter : null;
    final delay = SyncBackoffPolicy.delayFor(
      retryCount: item.retryCount,
      retryAfter: retryAfter,
      jitterMilliseconds: _random.nextInt(3001),
    );
    final nextAttemptAt = await LocalDatabaseService.scheduleRetry(
      item.id,
      delay: delay,
      httpStatus: error is ApiException ? error.statusCode : null,
      error: _errorMessage(error),
      expectedGeneration: generation,
    );
    if (nextAttemptAt != null) {
      if (_contextKey != null) _pullPolicy.defer(_contextKey!, nextAttemptAt);
      _scheduleRetryAt(nextAttemptAt);
    }
  }

  static String _errorMessage(Object error) {
    final message = error is ApiException ? error.message : error.toString();
    return message.length <= 500 ? message : message.substring(0, 500);
  }

  static Future<void> _scheduleStoredRetry(int generation) async {
    final nextAttemptAt = await LocalDatabaseService.getNextRetryAt(
      expectedGeneration: generation,
    );
    if (nextAttemptAt != null) _scheduleRetryAt(nextAttemptAt);
  }

  static bool _isRetryableFailure(Object error) {
    return error is! ApiException ||
        classifyFailure(error) == SyncFailureDisposition.retry;
  }

  static void _scheduleTransientRetry(Object error) {
    final delay = SyncBackoffPolicy.delayFor(
      retryCount: _pullRetryCount,
      retryAfter: error is ApiException ? error.retryAfter : null,
      jitterMilliseconds: _random.nextInt(3001),
    );
    _pullRetryCount++;
    final dueAt = DateTime.now().toUtc().add(delay);
    _pullRetryDueAt = dueAt;
    if (_contextKey != null) _pullPolicy.defer(_contextKey!, dueAt);
    _scheduleRetryAt(dueAt);
  }

  static void _scheduleRetryAt(DateTime nextAttemptAt) {
    if (!_initialized || !_isAppActive || !ConnectivityService.isOnline.value) {
      return;
    }
    final existingDueAt = _retryDueAt;
    if (_retryTimer?.isActive == true &&
        existingDueAt != null &&
        !nextAttemptAt.isBefore(existingDueAt)) {
      return;
    }
    _retryTimer?.cancel();
    _retryDueAt = nextAttemptAt;
    final delay = nextAttemptAt.difference(DateTime.now().toUtc());
    final generation = AppDatabase.dataGeneration;
    final session = AuthService().sessionGeneration;
    _retryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (generation != AppDatabase.dataGeneration ||
          session != AuthService().sessionGeneration) {
        return;
      }
      _retryTimer = null;
      _retryDueAt = null;
      syncNow(force: true, pullChanges: _pullRetryCount > 0 || _deferredPull);
    });
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
    _ClinicalSyncRun run,
  ) async {
    final generation = run.generation;
    AppDatabase.ensureDataGeneration(generation);
    final since = await LocalDatabaseService.getLastSyncTime();
    AppDatabase.ensureDataGeneration(generation);
    final scopeVersion =
        AppDatabase.activeClinicalScopeVersion ??
        AuthService().clinicalScopeVersion;
    if (scopeVersion < 1) {
      throw StateError('Cannot sync without an active clinical scope.');
    }
    final today = run.windowDate;
    final windowDay = '${today.year}-${today.month}-${today.day}';
    final previousWindowDay = await AppDatabase.getMetadata(
      'appointments:window_day',
    );
    run.ensureCurrent();
    String dateOnly(DateTime date) =>
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final changed = await ClinicalDeltaPull.run(
      scopeVersion: scopeVersion,
      ensureCurrent: run.ensureCurrent,
      requestPage: (cursor) async {
        final response = await ApiClient.instance.get(
          '/sync/pull',
          headers: run.headers,
          maxRetries: 0,
          query: {
            'since': since,
            'limit': '25',
            'scope_version': '$scopeVersion',
            'appointment_from': dateOnly(
              today.subtract(const Duration(days: 7)),
            ),
            'appointment_to': dateOnly(
              DateTime(today.year, today.month + 3, today.day),
            ),
            'appointment_since': previousWindowDay == windowDay
                ? since
                : '1970-01-01T00:00:00Z',
            'cursor': ?cursor,
          },
        );
        return Map<String, dynamic>.from(response.data['data'] as Map);
      },
      applyPatient: (row) => LocalDatabaseService.upsertPatientFromSync(
        row,
        expectedGeneration: generation,
      ),
      applyAppointment: (row) => LocalDatabaseService.upsertAppointmentFromSync(
        row,
        expectedGeneration: generation,
      ),
      commitCheckpoint: (serverTime) => AppDatabase.commitClinicalCheckpoint(
        serverTime: serverTime,
        windowDay: windowDay,
        expectedGeneration: generation,
      ),
      scopeChanged: () async {
        run.ensureCurrent();
        await AuthService().refreshCurrentUser();
        throw const StaleAccountDataException();
      },
    );
    return (changed: changed, generation: generation);
  }

  static void dispose() {
    _initialized = false;
    _reconnectTimer?.cancel();
    _writeDebounceTimer?.cancel();
    _retryTimer?.cancel();
    _retryDueAt = null;
    _pullRetryCount = 0;
    _pullRetryDueAt = null;
    _lastPullError = null;
    _deferredPull = false;
    _flights.clear();
    _contextKey = null;
    _pullPolicy.clear();
    final completer = _writeDebounceCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
    _writeDebounceCompleter = null;
    status.value = const SyncStatusSnapshot();
    ConnectivityService.isOnline.removeListener(_onConnectivityChanged);
    _syncCompleteListeners.clear();
    _dbReloadListeners.clear();
  }
}
