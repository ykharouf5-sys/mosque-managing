import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/student/data/subject_models.dart';
import 'academic_local_store.dart';
import 'package:uuid/uuid.dart';

class AcademicApiService {
  const AcademicApiService();

  static final ApiClient _api = ApiClient.instance;

  Future<List<Subject>> subjects() async {
    final response = await _api.get('/academic/subjects');
    return _maps(response.data['data']).map(Subject.fromJson).toList();
  }

  Future<Subject> createSubject(Subject subject) async {
    await AcademicLocalStore.enqueue(
      'subjects',
      subject.id,
      'POST',
      '/academic/subjects',
      _subjectPayload(subject, includeId: true, includeVersion: false),
      subject.toJson(),
    );
    return subject;
  }

  Future<Subject> updateSubject(Subject subject) async {
    final updated = {...subject.toJson(), 'version': subject.version + 1};
    await AcademicLocalStore.enqueue(
      'subjects',
      subject.id,
      'PUT',
      '/academic/subjects/${subject.id}',
      _subjectPayload(subject, includeId: false, includeVersion: true),
      updated,
    );
    return Subject.fromJson(updated);
  }

  Future<void> deleteSubject(String id) async {
    await AcademicLocalStore.enqueue(
      'subjects',
      id,
      'DELETE',
      '/academic/subjects/$id',
      {},
      null,
    );
  }

  Future<List<StudentSubject>> enrollments() async {
    final response = await _api.get('/academic/enrollments');
    return _maps(response.data['data']).map(StudentSubject.fromJson).toList();
  }

  Future<StudentSubject> createEnrollment(StudentSubject enrollment) async {
    final id = const Uuid().v4();
    final created = {...enrollment.toJson(), 'enrollmentId': id, 'version': 1};
    await AcademicLocalStore.enqueue(
      'enrollments',
      id,
      'POST',
      '/academic/enrollments',
      {
        ..._enrollmentPayload(
          enrollment,
          includeId: true,
          includeVersion: false,
        ),
        'id': id,
      },
      created,
    );
    return StudentSubject.fromJson(created);
  }

  Future<StudentSubject> updateEnrollment(StudentSubject enrollment) async {
    final updated = {...enrollment.toJson(), 'version': enrollment.version + 1};
    await AcademicLocalStore.enqueue(
      'enrollments',
      enrollment.enrollmentId,
      'PUT',
      '/academic/enrollments/${enrollment.enrollmentId}',
      _enrollmentPayload(enrollment, includeId: false, includeVersion: true),
      updated,
    );
    return StudentSubject.fromJson(updated);
  }

  Future<StudentSubject> markLectureViewed(
    StudentSubject enrollment,
    int lectureNumber,
  ) async {
    final updated = {
      ...enrollment.toJson(),
      'version': enrollment.version + 1,
      'viewedLectures': {...enrollment.viewedLectures, lectureNumber}.toList(),
    };
    await AcademicLocalStore.enqueue(
      'enrollments',
      enrollment.enrollmentId,
      'PATCH',
      '/academic/enrollments/${enrollment.enrollmentId}/viewed',
      {'lecture_number': lectureNumber, 'version': enrollment.version},
      updated,
    );
    return StudentSubject.fromJson(updated);
  }

  Future<void> deleteEnrollment(String enrollmentId) async {
    await AcademicLocalStore.enqueue(
      'enrollments',
      enrollmentId,
      'DELETE',
      '/academic/enrollments/$enrollmentId',
      {},
      null,
    );
  }

  static Map<String, dynamic> _subjectPayload(
    Subject subject, {
    required bool includeId,
    required bool includeVersion,
  }) => {
    if (includeId) 'id': subject.id,
    'name': subject.name,
    'code': subject.code,
    'academic_year': subject.academicYear,
    'doctor_name': subject.doctorName,
    'color': subject.color,
    'total_lectures': subject.totalLectures,
    'theoretical_hours': subject.theoreticalHours,
    'practical_hours': subject.practicalHours,
    'lectures': subject.lectures.map((lecture) => lecture.toJson()).toList(),
    'pdf_url': subject.pdfReference,
    if (includeVersion) 'version': subject.version,
  };

  static Map<String, dynamic> _enrollmentPayload(
    StudentSubject enrollment, {
    required bool includeId,
    required bool includeVersion,
  }) => {
    if (includeId && !enrollment.isCustom) 'subject_id': enrollment.subjectId,
    if (includeId) 'is_custom': enrollment.isCustom,
    'name': enrollment.name,
    'code': enrollment.code,
    'academic_year': enrollment.academicYear,
    'doctor_name': enrollment.doctorName,
    'color': enrollment.color,
    'schedule_days': enrollment.scheduleDays,
    'schedule_times': enrollment.scheduleTimes,
    'hall': enrollment.hall,
    'next_lecture': enrollment.nextLecture,
    'total_lectures': enrollment.totalLectures,
    'theoretical_hours': enrollment.theoreticalHours,
    'practical_hours': enrollment.practicalHours,
    if (includeVersion) 'version': enrollment.version,
  };

  static Map<String, dynamic> _map(dynamic value) =>
      Map<String, dynamic>.from(value as Map);

  static List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List).map(_map).toList();
}
