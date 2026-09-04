import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

String _colorToHex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

Color _hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse(h, radix: 16));
}

class TreatmentItem {
  String procedureName, status;
  Color statusColor;
  TreatmentItem({
    required this.procedureName,
    required this.status,
    required this.statusColor,
  });

  Map<String, dynamic> toJson() => {
    'procedureName': procedureName,
    'status': status,
    'statusColor': _colorToHex(statusColor),
  };

  factory TreatmentItem.fromJson(Map<String, dynamic> j) => TreatmentItem(
    procedureName: j['procedureName'] as String? ?? '',
    status: j['status'] as String? ?? 'معلق',
    statusColor: _hexToColor(j['statusColor'] as String? ?? '#FFFFA000'),
  );
}

class PatientProfile {
  final String id, photoUrl;
  String name, phone;
  int age;
  String address, registrationDate, notes;
  double amountDue, amountPaid, todayPayment;
  DateTime? appointmentDate;
  final List<TreatmentItem> treatmentPlan;
  final List<String> photos;

  PatientProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.age,
    required this.address,
    required this.registrationDate,
    required this.notes,
    required this.photoUrl,
    this.amountDue = 0,
    this.amountPaid = 0,
    this.todayPayment = 0,
    this.appointmentDate,
    required this.treatmentPlan,
    List<String>? photos,
  }) : photos = photos ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'age': age,
    'address': address,
    'registrationDate': registrationDate,
    'notes': notes,
    'photoUrl': photoUrl,
    'amountDue': amountDue,
    'amountPaid': amountPaid,
    'todayPayment': todayPayment,
    'appointmentDate': appointmentDate?.toIso8601String(),
    'treatmentPlan': treatmentPlan.map((t) => t.toJson()).toList(),
    'photos': photos,
  };

  factory PatientProfile.fromJson(Map<String, dynamic> j) => PatientProfile(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    age: (j['age'] as num?)?.toInt() ?? 0,
    address: j['address'] as String? ?? '',
    registrationDate: j['registrationDate'] as String? ?? '',
    notes: j['notes'] as String? ?? '',
    photoUrl: j['photoUrl'] as String? ?? '',
    amountDue: (j['amountDue'] as num?)?.toDouble() ?? 0,
    amountPaid: (j['amountPaid'] as num?)?.toDouble() ?? 0,
    todayPayment: (j['todayPayment'] as num?)?.toDouble() ?? 0,
    appointmentDate: j['appointmentDate'] != null
        ? DateTime.parse(j['appointmentDate'] as String)
        : null,
    treatmentPlan: (j['treatmentPlan'] as List? ?? const [])
        .map((t) => TreatmentItem.fromJson(Map<String, dynamic>.from(t as Map)))
        .toList(),
    photos: List<String>.from(j['photos'] as List? ?? const []),
  );
}

class Appointment {
  final String id;
  String time, status;
  final String patientName, treatment, patientId;
  DateTime date;
  bool reminderSent, notificationSent;
  Appointment({
    String? id,
    required this.time,
    required this.patientName,
    required this.treatment,
    required this.status,
    required this.patientId,
    DateTime? date,
    this.reminderSent = false,
    this.notificationSent = false,
  }) : id = id ?? const Uuid().v4(),
       date = date ?? DateTime.now();

  DateTime get appointmentDateTime {
    final parts = time.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time,
    'status': status,
    'patientName': patientName,
    'treatment': treatment,
    'patientId': patientId,
    'date': date.toIso8601String(),
    'reminderSent': reminderSent,
    'notificationSent': notificationSent,
  };

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
    id: j['id'] as String?,
    time: j['time'] as String,
    patientName: j['patientName'] as String,
    treatment: j['treatment'] as String,
    status: j['status'] as String,
    patientId: j['patientId'] as String,
    date: DateTime.parse(j['date'] as String),
    reminderSent: j['reminderSent'] as bool? ?? false,
    notificationSent: j['notificationSent'] as bool? ?? false,
  );
}

int _nextId = 1028;
String generatePatientId() => const Uuid().v4();
int get currentNextId => _nextId;
set currentNextId(int v) => _nextId = v;

PatientProfile? patientRowToProfile(Map<String, dynamic> row) {
  try {
    final planList = row['treatmentPlan'] is String
        ? List<Map<String, dynamic>>.from(
            jsonDecode(row['treatmentPlan'] as String) as List,
          )
        : <Map<String, dynamic>>[];
    final photosList = row['photos'] is String
        ? List<String>.from(jsonDecode(row['photos'] as String) as List)
        : <String>[];
    return PatientProfile(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      age: (row['age'] as int?) ?? 0,
      address: row['address'] as String? ?? '',
      registrationDate: row['registrationDate'] as String? ?? '',
      notes: row['notes'] as String? ?? '',
      photoUrl: row['photoUrl'] as String? ?? '',
      amountDue: (row['amountDue'] as num?)?.toDouble() ?? 0,
      amountPaid: (row['amountPaid'] as num?)?.toDouble() ?? 0,
      todayPayment: (row['todayPayment'] as num?)?.toDouble() ?? 0,
      appointmentDate: row['appointmentDate'] != null
          ? DateTime.tryParse(row['appointmentDate'] as String)
          : null,
      treatmentPlan: planList
          .map(
            (t) => TreatmentItem(
              procedureName: t['procedureName'] as String? ?? '',
              status: t['status'] as String? ?? '',
              statusColor: _hexToColor(
                t['statusColor'] as String? ?? '#FF000000',
              ),
            ),
          )
          .toList(),
      photos: photosList,
    );
  } catch (e) {
    return null;
  }
}

Appointment? appointmentRowToAppointment(Map<String, dynamic> row) {
  try {
    return Appointment(
      id: row['id'] as String?,
      time: row['time'] as String? ?? '',
      patientName: row['patientName'] as String? ?? '',
      treatment: row['treatment'] as String? ?? '',
      status: row['status'] as String? ?? '',
      patientId: row['patientId'] as String? ?? '',
      date: DateTime.tryParse(row['date'] as String? ?? '') ?? DateTime.now(),
      reminderSent: (row['reminderSent'] as int?) == 1,
      notificationSent: (row['notificationSent'] as int?) == 1,
    );
  } catch (e) {
    return null;
  }
}

Map<String, dynamic> profileToPatientRow(PatientProfile p) {
  return {
    'id': p.id,
    'name': p.name,
    'phone': p.phone,
    'age': p.age,
    'address': p.address,
    'registrationDate': p.registrationDate,
    'notes': p.notes,
    'photoUrl': p.photoUrl,
    'amountDue': p.amountDue,
    'amountPaid': p.amountPaid,
    'todayPayment': p.todayPayment,
    'appointmentDate': p.appointmentDate?.toIso8601String(),
    'treatmentPlan': jsonEncode(
      p.treatmentPlan.map((t) => t.toJson()).toList(),
    ),
    'photos': jsonEncode(p.photos),
  };
}

Map<String, dynamic> appointmentToRow(Appointment a) {
  return {
    'id': a.id,
    'patientId': a.patientId,
    'patientName': a.patientName,
    'time': a.time,
    'status': a.status,
    'treatment': a.treatment,
    'date': a.date.toIso8601String(),
    'reminderSent': a.reminderSent ? 1 : 0,
    'notificationSent': a.notificationSent ? 1 : 0,
  };
}

// Kept for migration of legacy encrypted SQLite rows.
// ignore: unused_element
PatientProfile? _patientRowToProfile(Map<String, dynamic> row) {
  try {
    final planList = row['treatmentPlan'] is String
        ? List<Map<String, dynamic>>.from(
            jsonDecode(row['treatmentPlan'] as String) as List,
          )
        : <Map<String, dynamic>>[];
    final photosList = row['photos'] is String
        ? List<String>.from(jsonDecode(row['photos'] as String) as List)
        : <String>[];
    return PatientProfile(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      age: (row['age'] as int?) ?? 0,
      address: row['address'] as String? ?? '',
      registrationDate: row['registrationDate'] as String? ?? '',
      notes: row['notes'] as String? ?? '',
      photoUrl: row['photoUrl'] as String? ?? '',
      amountDue: (row['amountDue'] as num?)?.toDouble() ?? 0,
      amountPaid: (row['amountPaid'] as num?)?.toDouble() ?? 0,
      todayPayment: (row['todayPayment'] as num?)?.toDouble() ?? 0,
      appointmentDate: row['appointmentDate'] != null
          ? DateTime.tryParse(row['appointmentDate'] as String)
          : null,
      treatmentPlan: planList
          .map(
            (t) => TreatmentItem(
              procedureName: t['procedureName'] as String? ?? '',
              status: t['status'] as String? ?? '',
              statusColor: _hexToColor(
                t['statusColor'] as String? ?? '#FF000000',
              ),
            ),
          )
          .toList(),
      photos: photosList,
    );
  } catch (e) {
    return null;
  }
}

// ignore: unused_element
Appointment? _appointmentRowToAppointment(Map<String, dynamic> row) {
  try {
    return Appointment(
      id: row['id'] as String?,
      time: row['time'] as String? ?? '',
      patientName: row['patientName'] as String? ?? '',
      treatment: row['treatment'] as String? ?? '',
      status: row['status'] as String? ?? '',
      patientId: row['patientId'] as String? ?? '',
      date: DateTime.tryParse(row['date'] as String? ?? '') ?? DateTime.now(),
      reminderSent: (row['reminderSent'] as int?) == 1,
      notificationSent: (row['notificationSent'] as int?) == 1,
    );
  } catch (e) {
    return null;
  }
}

// ignore: unused_element
Map<String, dynamic> _profileToPatientRow(PatientProfile p) {
  return {
    'id': p.id,
    'name': p.name,
    'phone': p.phone,
    'age': p.age,
    'address': p.address,
    'registrationDate': p.registrationDate,
    'notes': p.notes,
    'photoUrl': p.photoUrl,
    'amountDue': p.amountDue,
    'amountPaid': p.amountPaid,
    'todayPayment': p.todayPayment,
    'appointmentDate': p.appointmentDate?.toIso8601String(),
    'treatmentPlan': jsonEncode(
      p.treatmentPlan.map((t) => t.toJson()).toList(),
    ),
    'photos': jsonEncode(p.photos),
  };
}

// ignore: unused_element
Map<String, dynamic> _appointmentToRow(Appointment a) {
  return {
    'id': a.id,
    'patientId': a.patientId,
    'patientName': a.patientName,
    'time': a.time,
    'status': a.status,
    'treatment': a.treatment,
    'date': a.date.toIso8601String(),
    'reminderSent': a.reminderSent ? 1 : 0,
    'notificationSent': a.notificationSent ? 1 : 0,
  };
}
