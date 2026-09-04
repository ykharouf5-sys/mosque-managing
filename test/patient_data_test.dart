import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/patients/data/patient_data.dart';

void main() {
  test('patient API parser tolerates nullable legacy demographic fields', () {
    final patient = PatientProfile.fromJson({
      'id': 'patient-1',
      'name': 'مريض قديم',
      'phone': null,
      'age': null,
      'address': null,
      'registrationDate': null,
      'notes': null,
      'photoUrl': null,
      'amountDue': 1200,
      'amountPaid': 200,
      'todayPayment': null,
      'appointmentDate': null,
      'treatmentPlan': null,
      'photos': null,
    });

    expect(patient.age, 0);
    expect(patient.phone, isEmpty);
    expect(patient.todayPayment, 0);
    expect(patient.treatmentPlan, isEmpty);
  });
}
