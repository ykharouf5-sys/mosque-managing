import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/student/data/academic_result_api_service.dart';
import 'package:studentry/student/data/result_models.dart';
import 'package:uuid/uuid.dart';

class StudentGradesService {
  static Future<void> saveSubjectGrades({
    required String subjectId,
    required String subjectName,
    required Map<String, double> grades,
  }) async {
    final now = DateTime.now().toUtc();
    final uploadId = const Uuid().v4();
    final records = grades.entries
        .map(
          (entry) => ResultRecord(
            id: const Uuid().v4(),
            examNumber: entry.key,
            subjectName: subjectName,
            mark: entry.value,
            status: entry.value >= 50 ? 'passed' : 'failed',
            uploadDate: now,
            sourcePdfId: uploadId,
          ),
        )
        .toList();
    await const AcademicResultApiService().save(
      ResultUpload(
        id: uploadId,
        fileName: 'manual-$subjectName.json',
        status: 'completed',
        totalRecords: records.length,
        importedRecords: records.length,
        uploadDate: now,
        processedDate: now,
        uploadedBy: AuthService().userId ?? '',
      ),
      records,
    );
  }
}
