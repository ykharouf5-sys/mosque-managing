import 'package:flutter/foundation.dart';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/data/auth_service.dart';
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
  String? _error;

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
    notifyListeners();
    final auth = AuthService();
    if (!auth.isLoggedIn || !auth.hasActiveClinicalMembership) return;
    await _load(generation);
  }

  Future<void> load({bool force = false}) async {
    final auth = AuthService();
    if (!auth.isLoggedIn || !auth.hasActiveClinicalMembership) return;
    if (_loading || (!force && _loaded)) return;
    await _load(_generation);
  }

  Future<void> _load(int generation) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final values = await Future.wait([_api.subjects(), _api.enrollments()]);
      _ensureGeneration(generation);
      _subjects
        ..clear()
        ..addAll(values[0] as List<Subject>);
      _enrollments
        ..clear()
        ..addAll(values[1] as List<StudentSubject>);
      _loaded = true;
    } on StaleSessionException {
      return;
    } catch (error) {
      if (generation == _generation) _error = error.toString();
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
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
    _sortSubjects();
    notifyListeners();
    return created;
  }

  Future<Subject> updateSubject(Subject subject) async {
    final generation = _generation;
    final updated = await _api.updateSubject(subject);
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
    notifyListeners();
    return updated;
  }

  Future<void> deleteSubject(String id) async {
    final generation = _generation;
    await _api.deleteSubject(id);
    _ensureGeneration(generation);
    _subjects.removeWhere((subject) => subject.id == id);
    _enrollments.removeWhere(
      (enrollment) => !enrollment.isCustom && enrollment.subjectId == id,
    );
    notifyListeners();
  }

  Future<StudentSubject> addEnrollment(StudentSubject enrollment) async {
    final generation = _generation;
    final created = await _api.createEnrollment(enrollment);
    _ensureGeneration(generation);
    _enrollments.add(created);
    notifyListeners();
    return created;
  }

  Future<StudentSubject> updateEnrollment(StudentSubject enrollment) async {
    final generation = _generation;
    final updated = await _api.updateEnrollment(enrollment);
    _ensureGeneration(generation);
    _replaceEnrollment(updated);
    notifyListeners();
    return updated;
  }

  Future<void> removeEnrollment(StudentSubject enrollment) async {
    final generation = _generation;
    await _api.deleteEnrollment(enrollment.enrollmentId);
    _ensureGeneration(generation);
    _enrollments.removeWhere(
      (item) => item.enrollmentId == enrollment.enrollmentId,
    );
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
