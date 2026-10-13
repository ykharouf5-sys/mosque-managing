import 'dart:async';
import 'dart:convert';

import 'package:studentry/patients/data/patient_data.dart';
import 'package:studentry/patients/data/notification_service.dart';
import 'package:studentry/patients/data/appointment_api_service.dart';
import 'package:studentry/shared/cache/cache_manager.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/shared/data/sync_service.dart';
import 'package:studentry/shared/data/clinical_sync_policy.dart';
import 'package:studentry/shared/data/api_request_queue.dart';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/data/sync_backoff.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final patientListProvider =
    NotifierProvider<PatientListNotifier, List<PatientProfile>>(
      PatientListNotifier.new,
    );

final localClinicalReportProvider = FutureProvider<ClinicalReportSummary>((
  ref,
) {
  Future<void> reload() async => ref.invalidateSelf();
  SyncService.addDbReloadListener(reload);
  ref.onDispose(() => SyncService.removeDbReloadListener(reload));
  return AppDatabase.getClinicalReportSummary();
});

class PatientListNotifier extends Notifier<List<PatientProfile>> {
  static const int pageSize = 25;
  final List<PatientProfile> _patients = [];
  int _loadedCount = 0;
  bool isLoadingMore = false;
  bool get hasMore => _loadedCount < _patients.length;

  List<PatientProfile> _display() => _patients.take(_loadedCount).toList();

  @override
  List<PatientProfile> build() {
    _loadedCount = pageSize.clamp(0, _patients.length);
    Future<void> reloadFromDatabase() => loadFromDb();

    SyncService.addDbReloadListener(reloadFromDatabase);
    ref.onDispose(() {
      SyncService.removeDbReloadListener(reloadFromDatabase);
    });
    return _display();
  }

  Future<void> loadFromDb() async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final rows = await AppDatabase.getAllPatients();
    if (!ref.mounted) return;
    AppDatabase.ensureDataGeneration(generation);
    _patients.clear();
    for (final row in rows) {
      final p = patientRowToProfile(row);
      if (p != null) _patients.add(p);
    }
    _cachePatients();
    _resetPagination();
  }

  Future<bool> refreshFromApi({bool force = false}) async {
    final generation = AppDatabase.dataGeneration;
    final session = AuthService().sessionGeneration;
    await loadFromDb();
    if (!ref.mounted ||
        generation != AppDatabase.dataGeneration ||
        session != AuthService().sessionGeneration) {
      return false;
    }
    final changed = await SyncService.syncNow(manual: force);
    if (!changed) await loadFromDb();
    return changed;
  }

  void _cachePatients() {
    if (_patients.isNotEmpty) {
      CacheManager.instance.set(
        'patients:all',
        _patients.map((p) => p.toJson()).toList(),
        tags: [CacheTags.patients],
        persist: false,
      );
    }
  }

  void _resetPagination() {
    _loadedCount = pageSize.clamp(0, _patients.length);
    isLoadingMore = false;
    state = _display();
  }

  void loadMore() {
    if (isLoadingMore || !hasMore) return;
    isLoadingMore = true;
    state = [...state];
    Future(() {
      _loadedCount = (_loadedCount + pageSize).clamp(0, _patients.length);
      isLoadingMore = false;
      state = _display();
    });
  }

  Future<void> add(
    PatientProfile patient, {
    double initialPayment = 0,
    String? initialPaymentId,
    Appointment? appointment,
  }) async {
    await AuthService().ensureLocalAccountActive();
    try {
      await AppDatabase.insertPatient(
        profileToPatientRow(patient),
        initialPayment: initialPayment,
        initialPaymentId: initialPaymentId,
        appointment: appointment == null ? null : appointmentToRow(appointment),
      );
    } on StateError catch (error) {
      if (error.message == 'appointment_time_conflict') {
        throw const AppointmentTimeConflictException();
      }
      rethrow;
    }
    _patients.insert(0, patient);
    _loadedCount = (_loadedCount + 1).clamp(1, _patients.length);
    ref.invalidate(patientDirectoryProvider);
    CacheManager.instance.invalidate(CacheTags.patients);
    state = _display();
    ref.invalidate(localClinicalReportProvider);
    if (appointment != null) {
      await ref.read(appointmentListProvider.notifier).loadFromDb();
    }
    unawaited(SyncService.syncNowWithJitter());
  }

  Future<void> remove(String id) async {
    await AuthService().ensureLocalAccountActive();
    await AppDatabase.softDeletePatient(id);
    ref.invalidate(patientDirectoryProvider);
    _patients.removeWhere((p) => p.id == id);
    _loadedCount = _loadedCount.clamp(0, _patients.length);
    CacheManager.instance.invalidate(CacheTags.patients);
    state = _display();
    ref.invalidate(localClinicalReportProvider);
    unawaited(SyncService.syncNowWithJitter());
  }

  Future<void> update(String id, PatientProfile updated) async {
    await AuthService().ensureLocalAccountActive();
    await AppDatabase.updatePatient(id, profileToPatientRow(updated));
    ref.invalidate(patientDirectoryProvider);
    final idx = _patients.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      _patients[idx] = updated;
      CacheManager.instance.invalidate(CacheTags.patients);
      if (idx < _loadedCount) state = _display();
    }
    ref.invalidate(localClinicalReportProvider);
    unawaited(SyncService.syncNowWithJitter());
  }

  void setList(List<PatientProfile> patients) {
    _patients
      ..clear()
      ..addAll(patients);
    _loadedCount = pageSize.clamp(0, _patients.length);
    _cachePatients();
    state = _display();
  }

  void refresh() {
    state = _display();
  }
}

/// Database-backed directory pagination used by the full patients screen.
/// Dashboards and reports keep their separate complete working set.
final patientDirectoryProvider =
    NotifierProvider<PatientDirectoryNotifier, List<PatientProfile>>(
      PatientDirectoryNotifier.new,
    );

class PatientDirectoryNotifier extends Notifier<List<PatientProfile>> {
  static const pageSize = 25;
  bool isLoadingMore = false;
  bool hasMore = true;
  bool _loadingFirstPage = false;

  @override
  List<PatientProfile> build() {
    Future<void> reload() => loadFirstPage();
    SyncService.addDbReloadListener(reload);
    ref.onDispose(() => SyncService.removeDbReloadListener(reload));
    Future.microtask(loadFirstPage);
    return const [];
  }

  Future<void> loadFirstPage() async {
    if (_loadingFirstPage) return;
    _loadingFirstPage = true;
    try {
      await AuthService().ensureLocalAccountActive();
      if (!ref.mounted) return;
      final generation = AppDatabase.captureActiveDataGeneration();
      final rows = await AppDatabase.getPatientsPage(0, pageSize);
      if (!ref.mounted) return;
      AppDatabase.ensureDataGeneration(generation);
      final patients = rows
          .map(patientRowToProfile)
          .whereType<PatientProfile>();
      state = patients.toList(growable: false);
      hasMore = rows.length == pageSize;
      isLoadingMore = false;
    } finally {
      _loadingFirstPage = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore || _loadingFirstPage) return;
    isLoadingMore = true;
    state = [...state];
    try {
      final generation = AppDatabase.captureActiveDataGeneration();
      final rows = await AppDatabase.getPatientsPage(state.length, pageSize);
      if (!ref.mounted) return;
      AppDatabase.ensureDataGeneration(generation);
      final knownIds = state.map((patient) => patient.id).toSet();
      final next = rows
          .map(patientRowToProfile)
          .whereType<PatientProfile>()
          .where((patient) => knownIds.add(patient.id));
      state = [...state, ...next];
      hasMore = rows.length == pageSize;
    } finally {
      isLoadingMore = false;
      if (ref.mounted) state = [...state];
    }
  }

  Future<void> refreshFromApi({bool force = false}) async {
    final generation = AppDatabase.dataGeneration;
    final session = AuthService().sessionGeneration;
    await loadFirstPage();
    if (!ref.mounted ||
        generation != AppDatabase.dataGeneration ||
        session != AuthService().sessionGeneration) {
      return;
    }
    final changed = await SyncService.syncNow(manual: force);
    if (!changed) await loadFirstPage();
  }
}

final appointmentListProvider =
    NotifierProvider<AppointmentListNotifier, List<Appointment>>(
      AppointmentListNotifier.new,
    );

class AppointmentTimeConflictException implements Exception {
  const AppointmentTimeConflictException();

  @override
  String toString() => 'هذا الوقت محجوز لموعد آخر.';
}

class AppointmentDatePage {
  final List<Appointment> appointments;
  final int currentPage;
  final int lastPage;

  const AppointmentDatePage({
    required this.appointments,
    required this.currentPage,
    required this.lastPage,
  });
}

class AppointmentListNotifier extends Notifier<List<Appointment>> {
  final Map<String, ClinicalSyncPolicy> _datePolicies = {};
  static const int pageSize = 25;
  final List<Appointment> _appointments = [];
  int _loadedCount = 0;
  bool isLoadingMore = false;
  bool get hasMore => _loadedCount < _appointments.length;

  List<Appointment> _display() => _appointments.take(_loadedCount).toList();

  @override
  List<Appointment> build() {
    _loadedCount = pageSize.clamp(0, _appointments.length);
    Future<void> reloadFromDatabase() => loadFromDb();

    SyncService.addDbReloadListener(reloadFromDatabase);
    ref.onDispose(() {
      SyncService.removeDbReloadListener(reloadFromDatabase);
    });
    return _display();
  }

  Future<void> loadFromDb() async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final rows = await AppDatabase.getAllAppointments();
    if (!ref.mounted) return;
    AppDatabase.ensureDataGeneration(generation);
    _appointments.clear();
    for (final row in rows) {
      final a = appointmentRowToAppointment(row);
      if (a != null) _appointments.add(a);
    }
    _cacheAppointments();
    _resetPagination();
    await NotificationService.scheduleAllAppointments(_appointments);
  }

  Future<AppointmentDatePage> loadDatePage(
    DateTime date, {
    int page = 1,
    bool remote = false,
    bool manual = false,
  }) async {
    await AuthService().ensureLocalAccountActive();
    final generation = AppDatabase.captureActiveDataGeneration();
    Future<AppointmentDatePage> localPage() async {
      final rows = await AppDatabase.getAppointmentsForDate(date);
      AppDatabase.ensureDataGeneration(generation);
      final start = (page - 1) * pageSize;
      final end = (start + pageSize).clamp(0, rows.length);
      final local = start >= rows.length
          ? const <Map<String, dynamic>>[]
          : rows.sublist(start, end);
      return AppointmentDatePage(
        appointments: local
            .map(appointmentRowToAppointment)
            .whereType<Appointment>()
            .toList(growable: false),
        currentPage: page,
        lastPage: rows.isEmpty ? 1 : ((rows.length + pageSize - 1) ~/ pageSize),
      );
    }

    if (!remote) return localPage();
    final dateKey = '${date.year}-${date.month}-${date.day}:$page';
    if (!_datePolicies.containsKey(dateKey) && _datePolicies.length >= 64) {
      _datePolicies.remove(_datePolicies.keys.first);
    }
    final policy = _datePolicies.putIfAbsent(dateKey, ClinicalSyncPolicy.new);
    final context = jsonEncode([
      AuthService().userId,
      AuthService().clinicId,
      AuthService().sessionGeneration,
      generation,
      AppDatabase.activeClinicalScopeVersion,
      dateKey,
    ]);
    if (!policy.allowPull(context, manual: manual)) return localPage();
    final clinicalHeaders = Map<String, String>.unmodifiable({
      'X-Clinical-Clinic': AuthService().clinicId ?? '',
      'X-Clinical-Scope-Version':
          '${AppDatabase.activeClinicalScopeVersion ?? AuthService().clinicalScopeVersion}',
    });
    try {
      final remote = await AppointmentApiService.fetchDatePage(
        date,
        page: page,
        pageSize: pageSize,
        force: manual,
        clinicalHeaders: clinicalHeaders,
      );
      AppDatabase.ensureDataGeneration(generation);
      final pageAppointments = <String, Appointment>{};
      for (final row in remote.rows) {
        final localRow = AppointmentApiService.toLocalRow(row);
        await AppDatabase.upsertAppointmentFromSync(
          localRow,
          expectedGeneration: generation,
        );
        // Render the committed local row. A stale REST page must not display
        // a pending deletion or an older version that the database rejected.
        final committed = await AppDatabase.getAppointmentById(
          localRow['id'] as String,
        );
        AppDatabase.ensureDataGeneration(generation);
        final appointment = committed == null
            ? null
            : appointmentRowToAppointment(committed);
        final appointmentId = appointment?.id;
        if (appointment != null &&
            appointmentId != null &&
            appointment.date.year == date.year &&
            appointment.date.month == date.month &&
            appointment.date.day == date.day) {
          pageAppointments[appointmentId] = appointment;
        }
      }
      // Pending local edits win over the server snapshot until their outbox
      // operations are accepted. This keeps offline additions visible.
      final pendingRows = await AppDatabase.getAppointmentsForDate(
        date,
        unsyncedOnly: true,
      );
      for (final row in pendingRows) {
        final appointment = appointmentRowToAppointment(row);
        final appointmentId = appointment?.id;
        if (appointment != null && appointmentId != null) {
          pageAppointments[appointmentId] = appointment;
        }
      }
      await loadFromDb();
      AppDatabase.ensureDataGeneration(generation);
      policy.succeeded(context);
      return AppointmentDatePage(
        appointments: pageAppointments.values.toList(growable: false)
          ..sort((a, b) => a.time.compareTo(b.time)),
        currentPage: remote.currentPage,
        lastPage: remote.lastPage,
      );
    } on StaleAccountDataException {
      rethrow;
    } catch (error) {
      AppDatabase.ensureDataGeneration(generation);
      if (error is ApiException &&
          error.statusCode == 403 &&
          error.details is Map &&
          (error.details as Map)['code'] == 'clinical_scope_changed') {
        try {
          await AuthService().refreshCurrentUser();
        } on StaleSessionException {
          rethrow;
        } on StaleAccountDataException {
          rethrow;
        } catch (_) {
          // Keep the scoped local page when offline; never apply the rejected
          // server page or bind old rows to a newly selected clinic.
        }
        AppDatabase.ensureDataGeneration(generation);
      }
      if (error is ApiException && error.statusCode == 429) {
        policy.defer(
          context,
          DateTime.now().add(
            SyncBackoffPolicy.delayFor(
              retryCount: 0,
              retryAfter: error.retryAfter,
            ),
          ),
        );
      }
      return localPage();
    }
  }

  void _cacheAppointments() {
    if (_appointments.isNotEmpty) {
      CacheManager.instance.set(
        'appointments:all',
        _appointments.map((a) => a.toJson()).toList(),
        tags: [CacheTags.appointments],
        persist: false,
      );
    }
  }

  void _resetPagination() {
    _loadedCount = pageSize.clamp(0, _appointments.length);
    isLoadingMore = false;
    state = _display();
  }

  void loadMore() {
    if (isLoadingMore || !hasMore) return;
    isLoadingMore = true;
    state = [...state];
    Future(() {
      _loadedCount = (_loadedCount + pageSize).clamp(0, _appointments.length);
      isLoadingMore = false;
      state = _display();
    });
  }

  Future<void> add(Appointment appointment) async {
    await AuthService().ensureLocalAccountActive();
    if (_blocksTime(appointment.status) &&
        await AppDatabase.hasAppointmentConflict(
          appointment.date,
          appointment.time,
        )) {
      throw const AppointmentTimeConflictException();
    }
    await AppDatabase.insertAppointment(appointmentToRow(appointment));
    _appointments.insert(0, appointment);
    _loadedCount = (_loadedCount + 1).clamp(1, _appointments.length);
    CacheManager.instance.invalidate(CacheTags.appointments);
    state = _display();
    await NotificationService.scheduleAllAppointments(_appointments);
    unawaited(SyncService.syncNowWithJitter());
  }

  void remove(String patientId) {
    _appointments.removeWhere((a) => a.patientId == patientId);
    _loadedCount = _loadedCount.clamp(0, _appointments.length);
    CacheManager.instance.invalidate(CacheTags.appointments);
    state = _display();
    unawaited(NotificationService.scheduleAllAppointments(_appointments));
  }

  Future<void> removeById(String id) async {
    await AppDatabase.softDeleteAppointment(id);
    _appointments.removeWhere((a) => a.id == id);
    _loadedCount = _loadedCount.clamp(0, _appointments.length);
    CacheManager.instance.invalidate(CacheTags.appointments);
    state = _display();
    await NotificationService.scheduleAllAppointments(_appointments);
    unawaited(SyncService.syncNowWithJitter());
  }

  Future<void> update(String id, Appointment updated) async {
    await AuthService().ensureLocalAccountActive();
    if (_blocksTime(updated.status) &&
        await AppDatabase.hasAppointmentConflict(
          updated.date,
          updated.time,
          excludingId: id,
        )) {
      throw const AppointmentTimeConflictException();
    }
    final oldIndex = _appointments.indexWhere((a) => a.id == id);
    final wasCancelled =
        oldIndex >= 0 && _isCancelled(_appointments[oldIndex].status);
    await AppDatabase.updateAppointment(id, appointmentToRow(updated));
    final idx = _appointments.indexWhere((a) => a.id == id);
    if (idx >= 0) {
      _appointments[idx] = updated;
      CacheManager.instance.invalidate(CacheTags.appointments);
      if (idx < _loadedCount) state = _display();
    }
    if (!wasCancelled && _isCancelled(updated.status)) {
      await _offerNextWaitlisted(updated);
    }
    await NotificationService.onAppointmentAdded(updated);
    unawaited(SyncService.syncNowWithJitter());
  }

  void setList(List<Appointment> appointments) {
    _appointments
      ..clear()
      ..addAll(appointments);
    _loadedCount = pageSize.clamp(0, _appointments.length);
    _cacheAppointments();
    state = _display();
    unawaited(NotificationService.scheduleAllAppointments(_appointments));
  }

  void refresh() {
    state = _display();
  }

  bool _isCancelled(String status) =>
      const {'ملغي', 'cancelled', 'canceled'}.contains(status);

  bool _blocksTime(String status) => !const {
    'ملغي',
    'cancelled',
    'canceled',
    'قائمة انتظار',
    'waitlist',
    'متاح',
    'available',
  }.contains(status);

  Future<void> _offerNextWaitlisted(Appointment cancelled) async {
    final row = await AppDatabase.getFirstWaitlistedAppointment(
      cancelled.date,
      excludingId: cancelled.id,
    );
    final waiting = row == null ? null : appointmentRowToAppointment(row);
    if (waiting == null) return;
    final offered = Appointment(
      id: waiting.id,
      time: cancelled.time,
      patientName: waiting.patientName,
      treatment: waiting.treatment,
      status: 'متاح',
      patientId: waiting.patientId,
      date: cancelled.date,
      reminderSent: waiting.reminderSent,
      notificationSent: waiting.notificationSent,
    );
    await AppDatabase.updateAppointment(waiting.id, appointmentToRow(offered));
    final index = _appointments.indexWhere((a) => a.id == waiting.id);
    if (index >= 0) _appointments[index] = offered;
    state = _display();
  }
}

// ── Patients State (full-featured) ──

class PatientsState {
  final List<PatientProfile> patients;
  final bool isLoading;
  final String? error;

  const PatientsState({
    this.patients = const [],
    this.isLoading = false,
    this.error,
  });

  PatientsState copyWith({
    List<PatientProfile>? patients,
    bool? isLoading,
    String? error,
  }) {
    return PatientsState(
      patients: patients ?? this.patients,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PatientsNotifier extends Notifier<PatientsState> {
  @override
  PatientsState build() {
    return const PatientsState(isLoading: false);
  }

  void setList(List<PatientProfile> patients) {
    state = PatientsState(patients: patients, isLoading: false);
  }
}

final patientsProvider = NotifierProvider<PatientsNotifier, PatientsState>(
  PatientsNotifier.new,
);

// ── Appointments State ──

class AppointmentsState {
  final List<Appointment> appointments;
  final bool isLoading;
  final String? error;

  const AppointmentsState({
    this.appointments = const [],
    this.isLoading = false,
    this.error,
  });

  AppointmentsState copyWith({
    List<Appointment>? appointments,
    bool? isLoading,
    String? error,
  }) {
    return AppointmentsState(
      appointments: appointments ?? this.appointments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AppointmentsNotifier extends Notifier<AppointmentsState> {
  @override
  AppointmentsState build() {
    return const AppointmentsState(isLoading: false);
  }

  void setList(List<Appointment> appointments) {
    state = AppointmentsState(appointments: appointments, isLoading: false);
  }
}

final appointmentsProvider =
    NotifierProvider<AppointmentsNotifier, AppointmentsState>(
      AppointmentsNotifier.new,
    );
