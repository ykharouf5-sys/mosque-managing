import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/student/data/subject_models.dart';

class AcademicApiService {
  const AcademicApiService();

  static final ApiClient _api = ApiClient.instance;

  Future<List<Subject>> subjects() async {
    final response = await _api.get('/academic/subjects');
    return _maps(response.data['data']).map(Subject.fromJson).toList();
  }

  Future<Subject> createSubject(Subject subject) async {
    final response = await _api.post(
      '/academic/subjects',
      body: _subjectPayload(subject, includeId: true, includeVersion: false),
    );
    return Subject.fromJson(_map(response.data['data']));
  }

  Future<Subject> updateSubject(Subject subject) async {
    final response = await _api.put(
      '/academic/subjects/${subject.id}',
      body: _subjectPayload(subject, includeId: false, includeVersion: true),
    );
    return Subject.fromJson(_map(response.data['data']));
  }

  Future<void> deleteSubject(String id) async {
    await _api.delete('/academic/subjects/$id');
  }

  Future<List<StudentSubject>> enrollments() async {
    final response = await _api.get('/academic/enrollments');
    return _maps(response.data['data']).map(StudentSubject.fromJson).toList();
  }

  Future<StudentSubject> createEnrollment(StudentSubject enrollment) async {
    final response = await _api.post(
      '/academic/enrollments',
      body: _enrollmentPayload(
        enrollment,
        includeId: true,
        includeVersion: false,
      ),
    );
    return StudentSubject.fromJson(_map(response.data['data']));
  }

  Future<StudentSubject> updateEnrollment(StudentSubject enrollment) async {
    final response = await _api.put(
      '/academic/enrollments/${enrollment.enrollmentId}',
      body: _enrollmentPayload(
        enrollment,
        includeId: false,
        includeVersion: true,
      ),
    );
    return StudentSubject.fromJson(_map(response.data['data']));
  }

  Future<StudentSubject> markLectureViewed(
    StudentSubject enrollment,
    int lectureNumber,
  ) async {
    final response = await _api.patch(
      '/academic/enrollments/${enrollment.enrollmentId}/viewed',
      body: {'lecture_number': lectureNumber, 'version': enrollment.version},
    );
    return StudentSubject.fromJson(_map(response.data['data']));
  }

  Future<void> deleteEnrollment(String enrollmentId) async {
    await _api.delete('/academic/enrollments/$enrollmentId');
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
