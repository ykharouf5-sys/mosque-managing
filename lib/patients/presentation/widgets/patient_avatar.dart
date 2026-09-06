import 'dart:io';

import 'package:flutter/material.dart';
import 'package:studentry/utils/variable_colors.dart';

class PatientAvatar extends StatelessWidget {
  final String photoUrl;
  final double radius;

  const PatientAvatar({
    super.key,
    required this.photoUrl,
    required this.radius,
  });

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
    final value = photoUrl.trim();
    if (value.isEmpty) {
      return CircleAvatar(radius: radius, child: ClipOval(child: placeholder));
    }
    final image = value.startsWith('/') || value.contains(':\\')
        ? Image.file(
            File(value),
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder,
          )
        : Image.network(
            value,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder,
          );
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.transparent,
      child: ClipOval(child: image),
    );
  }
}
