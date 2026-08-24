import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/auth/presentation/pending_membership_screen.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/shared/providers/auth_provider.dart';

void main() {
  group('clinical membership parsing', () {
    test('parses pending membership and scope version defensively', () {
      final user = AuthUser.fromJson({
        'id': 'user-1',
        'email': 'student@example.com',
        'clinic_id': null,
        'membership_status': 'PENDING',
        'clinical_scope_version': '7',
        'permissions': ['catalog.read', 'patients.read', 'sync.use'],
      });

      expect(user.membershipStatus, 'pending');
      expect(user.clinicalScopeVersion, 7);
      expect(user.clinicId, isNull);
      expect(user.hasActiveClinicalMembership, isFalse);
      expect(user.hasPermission('catalog.read'), isTrue);
      expect(user.hasPermission('patients.read'), isFalse);
      expect(user.hasPermission('sync.use'), isFalse);
    });

    test('infers legacy membership from clinic id when status is absent', () {
      final active = AuthUser.fromJson({
        'id': 'active-user',
        'clinic_id': 'clinic-1',
        'permissions': <String>[],
      });
      final pending = AuthUser.fromJson({
        'id': 'pending-user',
        'permissions': <String>[],
      });

      expect(active.membershipStatus, 'active');
      expect(active.hasActiveClinicalMembership, isTrue);
      expect(active.clinicalScopeVersion, 0);
      expect(pending.membershipStatus, 'pending');
      expect(pending.hasActiveClinicalMembership, isFalse);
    });

    test('never enables clinical access without a clinic assignment', () {
      final user = AuthUser.fromJson({
        'id': 'unassigned-user',
        'clinic_id': null,
        'membership_status': 'active',
        'permissions': ['*'],
      });

      expect(user.hasActiveClinicalMembership, isFalse);
      expect(user.hasPermission('patients.read'), isFalse);
      expect(user.hasPermission('appointments.write'), isFalse);
      expect(user.hasPermission('sync.use'), isFalse);
      expect(user.hasPermission('catalog.read'), isTrue);
    });

    test('AuthState carries the server membership scope', () {
      final user = AuthUser.fromJson({
        'id': 'user-2',
        'role': 'student',
        'clinic_id': 'clinic-2',
        'membership_status': 'active',
        'clinical_scope_version': 12,
        'permissions': <String>[],
      });

      final state = AuthState.fromUser(user);

      expect(state.isLoggedIn, isTrue);
      expect(state.userId, 'user-2');
      expect(state.role, 'student');
      expect(state.clinicId, 'clinic-2');
      expect(state.membershipStatus, 'active');
      expect(state.clinicalScopeVersion, 12);
      expect(state.hasActiveClinicalMembership, isTrue);
    });

    test('secure offline session payload round-trips its account scope', () {
      final confirmedAt = DateTime.utc(2026, 8, 24, 12);
      final original = AuthUser.fromJson({
        'id': 'cached-user',
        'email': 'cached@example.test',
        'role': 'student',
        'clinic_id': 'clinic-cached',
        'membership_status': 'active',
        'clinical_scope_version': 9,
        'permissions': ['patients.read', 'sync.use'],
        'email_confirmed_at': confirmedAt.toIso8601String(),
      });

      final restored = AuthUser.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.clinicId, original.clinicId);
      expect(restored.clinicalScopeVersion, 9);
      expect(restored.permissions, original.permissions);
      expect(restored.emailConfirmedAt, confirmedAt);
    });

    test('rejects a session payload without an account identifier', () {
      expect(
        () => AuthUser.fromJson({'permissions': <String>[]}),
        throwsFormatException,
      );
    });
  });

  group('clinical membership gate', () {
    testWidgets('pending membership replaces the clinical child', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ClinicalMembershipGate(
              hasActiveMembership: false,
              child: Text('clinical-content'),
            ),
          ),
        ),
      );

      expect(find.text('حسابك بانتظار التفعيل'), findsOneWidget);
      expect(find.text('التحقق من حالة الحساب'), findsOneWidget);
      expect(find.text('clinical-content'), findsNothing);
    });

    testWidgets('active membership allows the clinical child', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ClinicalMembershipGate(
              hasActiveMembership: true,
              child: Text('clinical-content'),
            ),
          ),
        ),
      );

      expect(find.text('clinical-content'), findsOneWidget);
      expect(find.text('حسابك بانتظار التفعيل'), findsNothing);
    });
  });
}
