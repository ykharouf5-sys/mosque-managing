import 'package:dentalcare/patients/data/patient_data.dart';

abstract class PatientRepository {
  // ── Patients ──
  Stream<List<PatientProfile>> watchPatients(String doctorId);
  Future<List<PatientProfile>> loadMorePatients();
  Future<void> addPatient(PatientProfile patient);
  Future<void> updatePatient(PatientProfile patient);
  Future<void> deletePatient(String patientId);
  bool get hasMorePatients;
  bool get isLoadingMore;

  // ── Appointments ──
  Stream<List<Appointment>> watchAppointments(String doctorId);
  Future<List<Appointment>> loadMoreAppointments();
  Future<void> addAppointment(Appointment appointment);
  Future<void> updateAppointment(Appointment appointment);
  Future<void> deleteAppointment(String patientId, String time);
  bool get hasMoreAppointments;
  bool get isLoadingMoreAppointments;
}
