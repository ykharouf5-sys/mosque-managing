import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:studentry/patients/presentation/widgets/patient_avatar.dart';

@Preview(name: 'أيقونة ملف المريض', group: 'المرضى', size: Size(180, 180))
Widget patientAvatarPreview() => const MaterialApp(
  home: Scaffold(body: Center(child: PatientAvatar(radius: 48))),
);
