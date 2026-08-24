import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dentalcare/patients/data/patient_data.dart';

class StorageService {
  static const _patientsIndex = 'pt_idx';
  static const _appointmentsIndex = 'apt_idx';
  static const _nextIdKey = 'next_patient_id';
  static const _patientPrefix = 'pt_';
  static const _appointmentPrefix = 'apt_';

  static final FlutterSecureStorage _secure = const FlutterSecureStorage();

  static Future<void> save({
    List<PatientProfile>? patients,
    List<Appointment>? appointments,
  }) async {
    try {
      final pts = patients;
      final apts = appointments;
      if (pts != null) {
        final ids = pts.map((p) => p.id).toList();
        await _secure.write(key: _patientsIndex, value: jsonEncode(ids));
        for (final patient in pts) {
          await _secure.write(
            key: '$_patientPrefix${patient.id}',
            value: jsonEncode(patient.toJson()),
          );
        }
      }
      if (apts != null) {
        final aptKeys = apts.map((a) => '${a.patientId}_${a.time}').toList();
        await _secure.write(
          key: _appointmentsIndex,
          value: jsonEncode(aptKeys),
        );
        for (final apt in apts) {
          await _secure.write(
            key: '$_appointmentPrefix${apt.patientId}_${apt.time}',
            value: jsonEncode(apt.toJson()),
          );
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_nextIdKey, currentNextId);
    } catch (e) {
      debugPrint('StorageService.save error: $e');
    }
  }

  static Future<Map<String, dynamic>> load() async {
    final result = <String, dynamic>{
      'patients': <PatientProfile>[],
      'appointments': <Appointment>[],
    };
    try {
      final idsStr = await _secure.read(key: _patientsIndex);
      if (idsStr != null && idsStr.isNotEmpty) {
        final ids = List<String>.from(jsonDecode(idsStr) as List);
        final patients = <PatientProfile>[];
        for (final id in ids) {
          final dataStr = await _secure.read(key: '$_patientPrefix$id');
          if (dataStr != null) {
            try {
              patients.add(
                PatientProfile.fromJson(
                  jsonDecode(dataStr) as Map<String, dynamic>,
                ),
              );
            } catch (_) {
              debugPrint('Corrupted patient record: $id — skipped');
            }
          }
        }
        result['patients'] = patients;
      }

      final aptStr = await _secure.read(key: _appointmentsIndex);
      if (aptStr != null && aptStr.isNotEmpty) {
        final keys = List<String>.from(jsonDecode(aptStr) as List);
        final appointments = <Appointment>[];
        for (final key in keys) {
          final dataStr = await _secure.read(key: '$_appointmentPrefix$key');
          if (dataStr != null) {
            try {
              appointments.add(
                Appointment.fromJson(
                  jsonDecode(dataStr) as Map<String, dynamic>,
                ),
              );
            } catch (_) {
              debugPrint('Corrupted appointment record: $key — skipped');
            }
          }
        }
        result['appointments'] = appointments;
      }

      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getInt(_nextIdKey);
      if (savedId != null) currentNextId = savedId;
    } catch (e) {
      debugPrint('StorageService.load error: $e');
    }
    return result;
  }

  static Future<String?> get(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (e) {
      debugPrint('StorageService.get error: $e');
      return null;
    }
  }

  static Future<void> set(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (e) {
      debugPrint('StorageService.set error: $e');
    }
  }

  // ─── Secure registration data (PII) ───
  static const _regNameKey = 'reg_name';
  static const _regEmailKey = 'reg_email';
  static const _regPhoneKey = 'reg_phone';
  static const _regRoleKey = 'reg_role';
  static const _regAcademicYearKey = 'reg_academic_year';

  static Future<void> saveRegistrationData({
    required String name,
    required String email,
    required String phone,
    String? role,
    String? academicYear,
  }) async {
    await _secure.write(key: _regNameKey, value: name);
    await _secure.write(key: _regEmailKey, value: email);
    await _secure.write(key: _regPhoneKey, value: phone);
    if (role != null) await _secure.write(key: _regRoleKey, value: role);
    if (academicYear != null) {
      await _secure.write(key: _regAcademicYearKey, value: academicYear);
    }
  }

  static Future<Map<String, String?>> getRegistrationData() async {
    return {
      'name': await _secure.read(key: _regNameKey),
      'email': await _secure.read(key: _regEmailKey),
      'phone': await _secure.read(key: _regPhoneKey),
      'role': await _secure.read(key: _regRoleKey),
      'academicYear': await _secure.read(key: _regAcademicYearKey),
    };
  }

  static Future<void> clearRegistrationData() async {
    await _secure.delete(key: _regNameKey);
    await _secure.delete(key: _regEmailKey);
    await _secure.delete(key: _regPhoneKey);
    await _secure.delete(key: _regRoleKey);
    await _secure.delete(key: _regAcademicYearKey);
  }
}
