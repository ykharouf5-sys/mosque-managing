import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:studentry/patients/presentation/widgets/appointment_form_overview.dart';

@Preview(name: 'بطاقة موعد جديد', group: 'المواعيد', size: Size(393, 360))
Widget appointmentFormOverviewPreview() {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: AppointmentFormOverview(
          patientName: 'محمد أحمد',
          date: DateTime(2026, 9, 28),
          time: const TimeOfDay(hour: 10, minute: 30),
          onChooseDateTime: () {},
        ),
      ),
    ),
  );
}
