import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/shared/providers/auth_provider.dart';

void finishAuthentication(AuthUser user, BuildContext context, WidgetRef ref) {
  ref.read(authProvider.notifier).setAuthUser(user);
  final String destination;
  if (user.role == 'student' && !user.profileCompleted) {
    destination = '/student-profile';
  } else {
    destination = switch (user.role) {
      'admin' || 'sales_manager' => '/sales-dashboard',
      'student_manager' => '/student-admin',
      'warehouse_manager' => '/warehouse-dashboard',
      _ => '/student-home',
    };
  }
  Navigator.pushNamedAndRemoveUntil(context, destination, (_) => false);
}
