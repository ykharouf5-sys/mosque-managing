import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/auth/presentation/auth_mixin.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/shared/providers/auth_provider.dart';

class GoogleLoginHarness extends ConsumerStatefulWidget {
  final Future<AuthUser> Function() authenticate;
  const GoogleLoginHarness({super.key, required this.authenticate});
  @override
  ConsumerState<GoogleLoginHarness> createState() => _GoogleLoginHarnessState();
}

class _GoogleLoginHarnessState extends ConsumerState<GoogleLoginHarness>
    with AuthMixin {
  @override
  Future<AuthUser> authenticateGoogleUser() => widget.authenticate();
  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ElevatedButton(
      onPressed: () => signInWithGoogle(selectedRole: 'admin'),
      child: const Text('Google login'),
    ),
  );
}

void main() {
  final cases = {
    'student': '/student-home',
    'admin': '/sales-dashboard',
    'sales_manager': '/sales-dashboard',
    'student_manager': '/student-admin',
    'warehouse_manager': '/warehouse-dashboard',
    'incomplete-student': '/student-profile',
  };
  for (final entry in cases.entries) {
    testWidgets('successful Google login leaves auth screen for ${entry.key}', (
      tester,
    ) async {
      final response = Completer<AuthUser>();
      var requests = 0;
      final user = AuthUser(
        id: 'fixture-user',
        emailConfirmedAt: DateTime(2026, 10, 12),
        userMetadata: {
          'role': entry.key == 'incomplete-student' ? 'student' : entry.key,
          'profile_completed': entry.key != 'incomplete-student',
        },
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: GoogleLoginHarness(
              authenticate: () {
                requests++;
                return response.future;
              },
            ),
            routes: {
              for (final name in cases.values.toSet())
                name: (_) => Scaffold(body: Text(name)),
            },
          ),
        ),
      );
      await tester.tap(find.text('Google login'));
      await tester.tap(find.text('Google login'));
      await tester.pump();
      expect(requests, 1);
      response.complete(user);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('Google login'), findsNothing);
      expect(container.read(authProvider).userId, user.id);
      expect(container.read(authProvider).role, user.role);
      expect(tester.takeException(), isNull);
    });
  }
}
