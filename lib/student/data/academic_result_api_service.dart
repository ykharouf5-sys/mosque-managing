import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'dart:convert';
import 'package:studentry/student/data/result_models.dart';

class AcademicResultApiService {
  const AcademicResultApiService();

  static final ApiClient _api = ApiClient.instance;

  Future<List<ResultUpload>> uploads() async {
    final all = <ResultUpload>[];
    var page = 1;
    var lastPage = 1;
    do {
      final response = await _api.get(
        '/academic/result-uploads',
        query: {'page': '$page', 'per_page': '50'},
      );
      final payload = _map(response.data['data']);
      all.addAll(_maps(payload['data']).map(ResultUpload.fromJson));
      lastPage = (payload['last_page'] as num?)?.toInt() ?? page;
      page++;
    } while (page <= lastPage);
    return all;
  }

  Future<List<ResultRecord>> uploadRecords(String uploadId) async {
    final response = await _api.get(
      '/academic/result-uploads/$uploadId/records',
    );
    return _maps(response.data['data']).map(ResultRecord.fromJson).toList();
  }

  Future<ResultUpload> save(
    ResultUpload upload,
    List<ResultRecord> records,
  ) async {
    final response = await _api.post(
      '/academic/result-uploads',
      headers: {'Idempotency-Key': upload.id},
      body: {
        'id': upload.id,
        'file_name': upload.fileName,
        'storage_path': upload.storagePath,
        'download_url': upload.downloadUrl,
        'warnings': upload.warnings,
        'exam_session': upload.examSession,
        'academic_year': upload.academicYear,
        'university': upload.university,
        'failed_records': upload.failedRecords,
        'records': records
            .map(
              (record) => {
                'id': record.id,
                'exam_number': record.examNumber,
                'student_name': record.studentName,
                'father_name': record.fatherName,
                'subject_name': record.subjectName,
                'subject_code': record.subjectCode,
                'theoretical_mark': record.theoreticalMark,
                'practical_mark': record.practicalMark,
                'mark': record.mark,
                'total': record.total,
                'status': record.status,
                'exam_session': record.examSession,
                'academic_year': record.academicYear,
                'examined_at': record.uploadDate.toUtc().toIso8601String(),
                'notes': record.notes,
              },
            )
            .toList(),
      },
    );
    return ResultUpload.fromJson(_map(response.data['data']));
  }

  Future<void> delete(String uploadId) async {
    await _api.delete('/academic/result-uploads/$uploadId');
  }

  Future<void> rematch(String uploadId) async {
    await _api.post('/academic/result-uploads/$uploadId/rematch');
  }

  Future<List<ResultRecord>> results({String? examNumber}) async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final response = await _api.get(
      '/academic/results',
      query: {
        if (examNumber != null && examNumber.isNotEmpty)
          'exam_number': examNumber,
      },
    );
    AppDatabase.ensureDataGeneration(generation);
    final results = _maps(
      response.data['data'],
    ).map(ResultRecord.fromJson).toList();
    await AppDatabase.setMetadata(
      _resultCacheKey(examNumber),
      jsonEncode(results.map((r) => r.toJson()).toList()),
      expectedGeneration: generation,
    );
    return results;
  }

  String _resultCacheKey(String? number) =>
      'academic:grades:${AuthService().hasPermission('grades.read_all') ? number ?? '' : AuthService().examNumber ?? ''}';

  Future<List<ResultRecord>> cachedResults({String? examNumber}) async {
    final generation = AppDatabase.captureActiveDataGeneration();
    final raw = await AppDatabase.getMetadata(_resultCacheKey(examNumber));
    AppDatabase.ensureDataGeneration(generation);
    return raw == null
        ? []
        : _maps(jsonDecode(raw)).map(ResultRecord.fromJson).toList();
  }

  static Map<String, dynamic> _map(dynamic value) =>
      Map<String, dynamic>.from(value as Map);

  static List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List).map(_map).toList();
}
