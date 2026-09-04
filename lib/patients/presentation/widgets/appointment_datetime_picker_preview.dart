import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:studentry/patients/presentation/widgets/appointment_datetime_picker.dart';

@Preview(name: 'منتقي موعد المريض', group: 'المواعيد', size: Size(393, 852))
Widget appointmentDateTimePickerPreview() {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton.icon(
            onPressed: () => showAppointmentDateTimePicker(
              context: context,
              initialDate: DateTime.now(),
              initialTime: const TimeOfDay(hour: 9, minute: 0),
            ),
            icon: const Icon(Icons.event_rounded),
            label: const Text('إضافة موعد'),
          ),
        ),
      ),
    ),
  );
}
