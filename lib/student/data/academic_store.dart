import 'package:flutter/foundation.dart';
import 'dart:async';
import 'academic_local_store.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/data/connectivity_service.dart';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/patients/data/notification_service.dart';
import 'package:studentry/student/data/academic_api_service.dart';
import 'package:studentry/student/data/subject_models.dart';
import 'package:uuid/uuid.dart';

class AcademicStore extends ChangeNotifier {
  AcademicStore._();

  static final AcademicStore instance = AcademicStore._();
  static const AcademicApiService _api = AcademicApiService();

  final List<Subject> _subjects = [];
  final List<StudentSubject> _enrollments = [];
  int _generation = 0;
  bool _loading = false;
  bool _loaded = false;
  Timer? _refreshTimer;
  Timer? _writeTimer;
  bool _watchingConnectivity = false;
  String? _error;
  DateTime? _retryAfter;
  int _failures = 0;
  String? _lectureReminderSignature;

  List<Subject> get subjects => List.unmodifiable(_subjects);
  List<StudentSubject> get enrollments => List.unmodifiable(_enrollments);
  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> rebindToCurrentSession() async {
    final generation = ++_generation;
    _subjects.clear();
    _enrollments.clear();
    _error = null;
    _loaded = false;
    _loading = false;
    _refreshTimer?.cancel();
    _writeTimer?.cancel();
    _retryAfter = null;
    _failures = 0;
    _lectureReminderSignature = null;
    notifyListeners();
    final auth = AuthService();
    if (!auth.isLoggedIn || !auth.hasPermission('subjects.read')) {
      await NotificationService.scheduleLectureNotifications(const []);
      return;
    }
    if (!_watchingConnectivity) {
      ConnectivityService.isOnline.addListener(_onConnectivity);
      _watchingConnectivity = true;
    }
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (ConnectivityService.isOnline.value &&
          (_retryAfter == null || DateTime.now().isAfter(_retryAfter!))) {
        unawaited(load(force: true));
      }
    });
    await _load(generation);
  }

  void _onConnectivity() {
    _retryAfter = null;
    if (ConnectivityService.isOnline.value) unawaited(load(force: true));
  }

  Future<void> discardPendingAndRefresh() async {
    if (_loading) return;
    await AcademicLocalStore.discardPending();
    await load(force: true);
  }

  Future<void> retryPending() async {
    if (_loading) return;
    await AcademicLocalStore.retryPending();
    await load(force: true);
  }

  void _syncSoon() {
    _writeTimer?.cancel();
    _writeTimer = Timer(
      const Duration(milliseconds: 500),
      () => load(force: true),
    );
  }

  Future<void> load({bool force = false}) async {
    final auth = AuthService();
    if (!auth.isLoggedIn || !auth.hasPermission('subjects.read')) return;
    if (_loading || (!force && _loaded)) return;
    await _load(_generation);
  }

  Future<void> _load(int generation) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final dataGeneration = AppDatabase.captureActiveDataGeneration();
      final cached = await Future.wait([
        AcademicLocalStore.read('subjects'),
        AcademicLocalStore.read('enrollments'),
      ]);
      _ensureGeneration(generation);
      _subjects
        ..clear()
        ..addAll(cached[0].map(Subject.fromJson));
      _enrollments
        ..clear()
        ..addAll(cached[1].map(StudentSubject.fromJson));
      await _syncLectureReminders();
      notifyListeners();
      if (!ConnectivityService.isOnline.value) return;
      await AcademicLocalStore.flush();
      final values = await Future.wait([_api.subjects(), _api.enrollments()]);
      _ensureGeneration(generation);
      await AcademicLocalStore.replace(
        'subjects',
        (values[0] as List<Subject>).map((s) => s.toJson()).toList(),
        dataGeneration,
      );
      await AcademicLocalStore.replace(
        'enrollments',
        (values[1] as List<StudentSubject>).map((s) => s.toJson()).toList(),
        dataGeneration,
      );
      final current = await Future.wait([
        AcademicLocalStore.read('subjects'),
        AcademicLocalStore.read('enrollments'),
      ]);
      _ensureGeneration(generation);
      _subjects
        ..clear()
        ..addAll(current[0].map(Subject.fromJson));
      _enrollments
        ..clear()
        ..addAll(current[1].map(StudentSubject.fromJson));
      await _syncLectureReminders();
      _loaded = true;
      _failures = 0;
      _retryAfter = null;
    } on StaleSessionException {
      return;
    } catch (error) {
      if (generation == _generation) {
        _error = error.toString();
        _failures = (_failures + 1).clamp(1, 6);
        _retryAfter = DateTime.now().add(
          Duration(seconds: 5 * (1 << _failures)),
        );
      }
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _syncLectureReminders() async {
    final signature =
        _enrollments
            .map(
              (item) => [
                item.subjectId,
                item.name,
                ...item.scheduleDays,
                ...item.scheduleTimes,
              ].join('|'),
            )
            .toList()
          ..sort();
    final nextSignature = signature.join('||');
    if (_lectureReminderSignature == nextSignature) return;
    await NotificationService.scheduleLectureNotifications(_enrollments);
    _lectureReminderSignature = nextSignature;
  }

  Future<Subject> addSubject({
    required String name,
    required String code,
    required String academicYear,
    String doctorName = '',
    String color = '#2196F3',
    int totalLectures = 20,
    int theoreticalHours = 0,
    int practicalHours = 0,
    String? pdfUrl,
  }) async {
    final generation = _generation;
    final created = await _api.createSubject(
      Subject(
        id: const Uuid().v4(),
        name: name,
        code: code,
        academicYear: academicYear,
        doctorName: doctorName,
        color: color,
        totalLectures: totalLectures,
        theoreticalHours: theoreticalHours,
        practicalHours: practicalHours,
        creditHours: theoreticalHours + (practicalHours / 2),
        lectures: Subject.generateLectures(totalLectures),
        pdfReference: pdfUrl,
      ),
    );
    _ensureGeneration(generation);
    _subjects.add(created);
    _syncSoon();
    _sortSubjects();
    notifyListeners();
    return created;
  }

  Future<Subject> updateSubject(Subject subject) async {
    final generation = _generation;
    final updated = await _api.updateSubject(subject);
    _syncSoon();
    _ensureGeneration(generation);
    final index = _subjects.indexWhere((item) => item.id == updated.id);
    if (index >= 0) _subjects[index] = updated;
    for (var i = 0; i < _enrollments.length; i++) {
      final enrollment = _enrollments[i];
      if (!enrollment.isCustom && enrollment.subjectId == updated.id) {
        _enrollments[i] = StudentSubject(
          enrollmentId: enrollment.enrollmentId,
          subjectId: updated.id,
          name: updated.name,
          code: updated.code,
          academicYear: updated.academicYear,
          doctorName: updated.doctorName,
          color: updated.color,
          scheduleDays: enrollment.scheduleDays,
          scheduleTimes: enrollment.scheduleTimes,
          hall: enrollment.hall,
          nextLecture: enrollment.nextLecture,
          totalLectures: updated.totalLectures,
          theoreticalHours: updated.theoreticalHours,
          practicalHours: updated.practicalHours,
          creditHours: updated.creditHours,
          grade: enrollment.grade,
          viewedLectures: enrollment.viewedLectures,
          version: enrollment.version + 1,
        );
      }
    }
    _sortSubjects();
    await _syncLectureReminders();
    notifyListeners();
    return updated;
  }

  Future<void> deleteSubject(String id) async {
    final generation = _generation;
    await _api.deleteSubject(id);
    _syncSoon();
    _ensureGeneration(generation);
    _subjects.removeWhere((subject) => subject.id == id);
    _enrollments.removeWhere(
      (enrollment) => !enrollment.isCustom && enrollment.subjectId == id,
    );
    await _syncLectureReminders();
    notifyListeners();
  }

  Future<StudentSubject> addEnrollment(StudentSubject enrollment) async {
    final generation = _generation;
    final created = await _api.createEnrollment(enrollment);
    _syncSoon();
    _ensureGeneration(generation);
    _enrollments.add(created);
    await _syncLectureReminders();
    notifyListeners();
    return created;
  }

  Future<StudentSubject> updateEnrollment(StudentSubject enrollment) async {
    final generation = _generation;
    final updated = await _api.updateEnrollment(enrollment);
    _syncSoon();
    _ensureGeneration(generation);
    _replaceEnrollment(updated);
    await _syncLectureReminders();
    notifyListeners();
    return updated;
  }

  Future<void> removeEnrollment(StudentSubject enrollment) async {
    final generation = _generation;
    await _api.deleteEnrollment(enrollment.enrollmentId);
    _syncSoon();
    _ensureGeneration(generation);
    _enrollments.removeWhere(
      (item) => item.enrollmentId == enrollment.enrollmentId,
    );
    await _syncLectureReminders();
    notifyListeners();
  }

  Future<StudentSubject> markLectureViewed(
    StudentSubject enrollment,
    int lectureNumber,
  ) async {
    final current = _enrollments.firstWhere(
      (item) => item.enrollmentId == enrollment.enrollmentId,
      orElse: () => enrollment,
    );
    if (current.viewedLectures.contains(lectureNumber)) return current;
    final generation = _generation;
    final updated = await _api.markLectureViewed(current, lectureNumber);
    _syncSoon();
    _ensureGeneration(generation);
    _replaceEnrollment(updated);
    notifyListeners();
    return updated;
  }

  void _replaceEnrollment(StudentSubject enrollment) {
    final index = _enrollments.indexWhere(
      (item) => item.enrollmentId == enrollment.enrollmentId,
    );
    if (index >= 0) _enrollments[index] = enrollment;
  }

  void _sortSubjects() {
    _subjects.sort((a, b) {
      final year = a.academicYear.compareTo(b.academicYear);
      return year == 0 ? a.name.compareTo(b.name) : year;
    });
  }

  void _ensureGeneration(int generation) {
    if (generation != _generation) throw const StaleSessionException();
  }
}
