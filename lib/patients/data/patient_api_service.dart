import 'package:studentry/patients/data/patient_data.dart';
import 'package:studentry/shared/data/api_client.dart';

class PatientPage {
  final List<Map<String, dynamic>> rows;
  final int currentPage;
  final int lastPage;

  const PatientPage({
    required this.rows,
    required this.currentPage,
    required this.lastPage,
  });

  bool get hasMore => currentPage < lastPage;
}

class PatientApiService {
  PatientApiService._();

  static final ApiClient _api = ApiClient.instance;
  static const int pageSize = 25;

  static Future<PatientPage> fetchPage(int page, {String? search}) async {
    final response = await _api.get(
      '/patients',
      query: {
        'page': '$page',
        'per_page': '$pageSize',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    final payload = Map<String, dynamic>.from(response.data['data'] as Map);
    return PatientPage(
      rows: (payload['data'] as List? ?? const [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
      currentPage: (payload['current_page'] as num?)?.toInt() ?? page,
      lastPage: (payload['last_page'] as num?)?.toInt() ?? page,
    );
  }

  static Future<Map<String, dynamic>> create(
    PatientProfile patient, {
    String? operationId,
  }) async {
    final response = await _api.post(
      '/patients',
      headers: {'Idempotency-Key': ?operationId},
      body: {'id': patient.id, 'data': patient.toJson()},
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  static Future<Map<String, dynamic>> update(
    PatientProfile patient, {
    int? version,
    String? operationId,
  }) async {
    final response = await _api.put(
      '/patients/${patient.id}',
      headers: {'Idempotency-Key': ?operationId},
      body: {'version': ?version, 'data': patient.toJson()},
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  static Future<void> delete(String patientId, {String? operationId}) async {
    await _api.delete(
      '/patients/$patientId',
      headers: {'Idempotency-Key': ?operationId},
    );
  }

  static Map<String, dynamic> toLocalRow(Map<String, dynamic> apiRow) {
    final profile = PatientProfile.fromJson(apiRow);
    return {
      ...profileToPatientRow(profile),
      'updated_at':
          apiRow['updated_at'] ?? DateTime.now().toUtc().toIso8601String(),
      'device_id': apiRow['device_id'] ?? 'server',
      'deleted_at': apiRow['deleted_at'],
      'version': (apiRow['version'] as num?)?.toInt() ?? 1,
    };
  }
}
