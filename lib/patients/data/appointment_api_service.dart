import 'package:dentalcare/shared/data/api_client.dart';

class AppointmentApiService {
  AppointmentApiService._();

  static final ApiClient _api = ApiClient.instance;

  static Future<Map<String, dynamic>> create(
    Map<String, dynamic> row, {
    required String operationId,
  }) async {
    final response = await _api.post(
      '/appointments',
      headers: {'Idempotency-Key': operationId},
      body: _body(row, includeId: true),
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  static Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> row, {
    required String operationId,
  }) async {
    final response = await _api.put(
      '/appointments/$id',
      headers: {'Idempotency-Key': operationId},
      body: _body(row, includeId: false),
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  static Future<void> delete(String id, {required String operationId}) async {
    await _api.delete(
      '/appointments/$id',
      headers: {'Idempotency-Key': operationId},
    );
  }

  static Map<String, dynamic> _body(
    Map<String, dynamic> row, {
    required bool includeId,
  }) {
    return {
      if (includeId) 'id': row['id'],
      if (!includeId) 'version': (row['version'] as num?)?.toInt() ?? 1,
      'device_id': row['device_id'],
      'data': {
        'patientId': row['patientId'],
        'patientName': row['patientName'],
        'time': row['time'],
        'status': row['status'],
        'treatment': row['treatment'],
        'date': row['date'],
        'reminderSent': _bool(row['reminderSent']),
        'notificationSent': _bool(row['notificationSent']),
      },
    };
  }

  static Map<String, dynamic> toLocalRow(Map<String, dynamic> apiRow) {
    return {
      'id': apiRow['id'],
      'patientId': apiRow['patientId'],
      'patientName': apiRow['patientName'] ?? '',
      'time': apiRow['time'] ?? '',
      'status': apiRow['status'] ?? '',
      'treatment': apiRow['treatment'] ?? '',
      'date': apiRow['date'] ?? apiRow['scheduled_at'],
      'reminderSent': _bool(apiRow['reminderSent']) ? 1 : 0,
      'notificationSent': _bool(apiRow['notificationSent']) ? 1 : 0,
      'updated_at': apiRow['updated_at'],
      'deleted_at': apiRow['deleted_at'],
      'device_id': apiRow['device_id'] ?? 'server',
      'version': (apiRow['version'] as num?)?.toInt() ?? 1,
    };
  }

  static bool _bool(dynamic value) => value == true || value == 1;
}
