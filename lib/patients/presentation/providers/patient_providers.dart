import 'package:studentry/patients/data/patient_data.dart';
import 'package:studentry/shared/cache/cache_manager.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/data/sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final patientListProvider =
    NotifierProvider<PatientListNotifier, List<PatientProfile>>(
      PatientListNotifier.new,
    );

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
    void reloadFromDatabase() {
      loadFromDb();
    }

    SyncService.addDbReloadListener(reloadFromDatabase);
    ref.onDispose(() {
      SyncService.removeDbReloadListener(reloadFromDatabase);
    });
    return _display();
  }

  Future<void> loadFromDb() async {
    final rows = await AppDatabase.getAllPatients();
    _patients.clear();
    for (final row in rows) {
      final p = patientRowToProfile(row);
      if (p != null) _patients.add(p);
    }
    _cachePatients();
    _resetPagination();
  }

  Future<void> refreshFromApi() async {
    await SyncService.syncNow();
    await loadFromDb();
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

  void add(PatientProfile patient) {
    _patients.add(patient);
    _loadedCount = _loadedCount.clamp(0, _patients.length);
    CacheManager.instance.invalidate(CacheTags.patients);
    AppDatabase.insertPatient(
      profileToPatientRow(patient),
    ).then((_) => SyncService.syncNowWithJitter());
    state = _display();
  }

  void remove(String id) {
    _patients.removeWhere((p) => p.id == id);
    _loadedCount = _loadedCount.clamp(0, _patients.length);
    CacheManager.instance.invalidate(CacheTags.patients);
    AppDatabase.softDeletePatient(
      id,
    ).then((_) => SyncService.syncNowWithJitter());
    state = _display();
  }

  void update(String id, PatientProfile updated) {
    final idx = _patients.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      _patients[idx] = updated;
      CacheManager.instance.invalidate(CacheTags.patients);
      AppDatabase.updatePatient(
        id,
        profileToPatientRow(updated),
      ).then((_) => SyncService.syncNowWithJitter());
      if (idx < _loadedCount) state = _display();
    }
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

final appointmentListProvider =
    NotifierProvider<AppointmentListNotifier, List<Appointment>>(
      AppointmentListNotifier.new,
    );

class AppointmentListNotifier extends Notifier<List<Appointment>> {
  static const int pageSize = 25;
  final List<Appointment> _appointments = [];
  int _loadedCount = 0;
  bool isLoadingMore = false;
  bool get hasMore => _loadedCount < _appointments.length;

  List<Appointment> _display() => _appointments.take(_loadedCount).toList();

  @override
  List<Appointment> build() {
    _loadedCount = pageSize.clamp(0, _appointments.length);
    void reloadFromDatabase() {
      loadFromDb();
    }

    SyncService.addDbReloadListener(reloadFromDatabase);
    ref.onDispose(() {
      SyncService.removeDbReloadListener(reloadFromDatabase);
    });
    return _display();
  }

  Future<void> loadFromDb() async {
    final rows = await AppDatabase.getAllAppointments();
    _appointments.clear();
    for (final row in rows) {
      final a = appointmentRowToAppointment(row);
      if (a != null) _appointments.add(a);
    }
    _cacheAppointments();
    _resetPagination();
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

  void add(Appointment appointment) {
    _appointments.add(appointment);
    _loadedCount = _loadedCount.clamp(0, _appointments.length);
    CacheManager.instance.invalidate(CacheTags.appointments);
    AppDatabase.insertAppointment(
      appointmentToRow(appointment),
    ).then((_) => SyncService.syncNowWithJitter());
    state = _display();
  }

  void remove(String patientId) {
    _appointments.removeWhere((a) => a.patientId == patientId);
    _loadedCount = _loadedCount.clamp(0, _appointments.length);
    CacheManager.instance.invalidate(CacheTags.appointments);
    state = _display();
  }

  void removeById(String id) {
    _appointments.removeWhere((a) => a.id == id);
    _loadedCount = _loadedCount.clamp(0, _appointments.length);
    CacheManager.instance.invalidate(CacheTags.appointments);
    AppDatabase.softDeleteAppointment(
      id,
    ).then((_) => SyncService.syncNowWithJitter());
    state = _display();
  }

  void update(String id, Appointment updated) {
    final idx = _appointments.indexWhere((a) => a.id == id);
    if (idx >= 0) {
      _appointments[idx] = updated;
      CacheManager.instance.invalidate(CacheTags.appointments);
      AppDatabase.updateAppointment(
        id,
        appointmentToRow(updated),
      ).then((_) => SyncService.syncNowWithJitter());
      if (idx < _loadedCount) state = _display();
    }
  }

  void setList(List<Appointment> appointments) {
    _appointments
      ..clear()
      ..addAll(appointments);
    _loadedCount = pageSize.clamp(0, _appointments.length);
    _cacheAppointments();
    state = _display();
  }

  void refresh() {
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
