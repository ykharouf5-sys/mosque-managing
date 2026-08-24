import 'package:studentry/shared/data/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  final String? userId;
  final String? role;
  final bool isLoggedIn;

  const AuthState({this.userId, this.role, this.isLoggedIn = false});

  AuthState copyWith({String? userId, String? role, bool? isLoggedIn}) {
    return AuthState(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final auth = AuthService();
    if (auth.isLoggedIn) {
      return AuthState(userId: auth.userId, role: auth.role, isLoggedIn: true);
    }
    return const AuthState();
  }

  void setAuth(String userId, String role) {
    state = AuthState(userId: userId, role: role, isLoggedIn: true);
  }

  void logout() {
    AuthService().signOut();
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
