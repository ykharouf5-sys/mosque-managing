import 'package:flutter/material.dart';
import 'package:studentry/utils/variable_colors.dart';

class PatientAvatar extends StatelessWidget {
  final double radius;

  const PatientAvatar({super.key, required this.radius});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppColors.primary.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: radius,
        color: AppColors.primary.withValues(alpha: 0.6),
      ),
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.transparent,
      child: ClipOval(child: placeholder),
    );
  }
}
