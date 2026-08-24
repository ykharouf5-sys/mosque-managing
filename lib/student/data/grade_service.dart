class StudentGradesService {
  static final Map<String, Map<String, double>> _gradeStore = {};

  static Future<void> saveSubjectGrades({
    required String subjectId,
    required String subjectName,
    required Map<String, double> grades,
  }) async {
    _gradeStore[subjectId] = grades;
  }

  static Map<String, double>? getGrades(String subjectId) =>
      _gradeStore[subjectId];
}
