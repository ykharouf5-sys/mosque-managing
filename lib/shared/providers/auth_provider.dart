import 'package:studentry/shared/data/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  final String? userId;
  final String? role;
  final String? clinicId;
  final String membershipStatus;
  final int clinicalScopeVersion;
  final bool isLoggedIn;

  const AuthState({
    this.userId,
    this.role,
    this.clinicId,
    this.membershipStatus = 'pending',
    this.clinicalScopeVersion = 0,
    this.isLoggedIn = false,
  });

  factory AuthState.fromUser(AuthUser user) => AuthState(
    userId: user.id,
    role: user.role,
    clinicId: user.clinicId,
    membershipStatus: user.membershipStatus,
    clinicalScopeVersion: user.clinicalScopeVersion,
    isLoggedIn: true,
  );

  bool get hasActiveClinicalMembership =>
      membershipStatus == 'active' && clinicId != null;

  AuthState copyWith({
    String? userId,
    String? role,
    String? clinicId,
    String? membershipStatus,
    int? clinicalScopeVersion,
    bool? isLoggedIn,
  }) {
    return AuthState(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      clinicId: clinicId ?? this.clinicId,
      membershipStatus: membershipStatus ?? this.membershipStatus,
      clinicalScopeVersion: clinicalScopeVersion ?? this.clinicalScopeVersion,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final auth = AuthService();
    final user = auth.currentUser;
    if (auth.isLoggedIn && user != null) {
      return AuthState.fromUser(user);
    }
    return const AuthState();
  }

  void setAuth(String userId, String role) {
    final currentUser = AuthService().currentUser;
    if (currentUser != null && currentUser.id == userId) {
      state = AuthState.fromUser(currentUser);
      return;
    }
    state = AuthState(userId: userId, role: role, isLoggedIn: true);
  }

  void setAuthUser(AuthUser user) => state = AuthState.fromUser(user);

  Future<void> logout() async {
    await AuthService().signOut();
    state = const AuthState();
  }

  Future<void> deleteAccount(String currentPassword) async {
    await AuthService().deleteAccount(currentPassword);
    state = const AuthState();
  }

  void clearAuth() {
    state = const AuthState();
  }

  void setRole(String role) {
    state = state.copyWith(role: role);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
