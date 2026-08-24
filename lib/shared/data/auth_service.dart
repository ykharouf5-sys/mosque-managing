import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../patients/data/photo_service.dart';

import 'api_client.dart';
import 'api_request_queue.dart';
import 'app_database.dart';
import 'fcm_token_service.dart';
import '../cache/cache_manager.dart';

class AuthUser {
  final String id;
  final String? email;
  final Map<String, dynamic> userMetadata;
  final DateTime? emailConfirmedAt;

  const AuthUser({
    required this.id,
    this.email,
    this.userMetadata = const {},
    this.emailConfirmedAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'].toString(),
    email: json['email']?.toString(),
    userMetadata: {
      'role': json['role'],
      'permissions': List<String>.from(
        json['permissions'] as List? ?? const [],
      ),
      'clinic_id': json['clinic_id'],
      'full_name': json['full_name'],
      'phone': json['phone'],
      'academic_year': json['academic_year'],
      'university': json['university'],
      'exam_number': json['exam_number'],
      'avatar_url': json['avatar_url'],
      'profile_completed': json['profile_completed'] == true,
    },
    emailConfirmedAt: DateTime.tryParse(
      json['email_confirmed_at']?.toString() ?? '',
    ),
  );
}

class AuthResponse {
  final AuthUser? user;
  const AuthResponse(this.user);
}

class OtpDispatch {
  final int expiresIn;
  final int resendAfter;

  const OtpDispatch({required this.expiresIn, required this.resendAfter});

  factory OtpDispatch.fromBody(dynamic body) {
    final data = body is Map ? body['data'] : null;
    final map = data is Map
        ? Map<String, dynamic>.from(data)
        : const <String, dynamic>{};
    return OtpDispatch(
      expiresIn: (map['expires_in'] as num?)?.toInt() ?? 600,
      resendAfter: (map['resend_after'] as num?)?.toInt() ?? 60,
    );
  }
}

class AuthSession {
  final AuthUser user;
  const AuthSession(this.user);
}

class AuthChangeEvent {
  final AuthSession? session;
  const AuthChangeEvent(this.session);
}

class AuthService {
  AuthService._();
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;

  static const _storage = FlutterSecureStorage();
  final _events = StreamController<AuthChangeEvent>.broadcast();
  String? _token;
  AuthUser? _user;

  AuthUser? get currentUser => _user;
  String? get userId => _user?.id;
  String? get email => _user?.email;
  String? get clinicId => _user?.userMetadata['clinic_id'] as String?;
  String? get role => _user?.userMetadata['role'] as String?;
  String? get fullName => _user?.userMetadata['full_name'] as String?;
  String? get phone => _user?.userMetadata['phone'] as String?;
  String? get academicYear => _user?.userMetadata['academic_year'] as String?;
  String? get university => _user?.userMetadata['university'] as String?;
  String? get examNumber => _user?.userMetadata['exam_number'] as String?;
  bool get profileCompleted => _user?.userMetadata['profile_completed'] == true;
  String? get avatarUrl => _user?.userMetadata['avatar_url'] as String?;

  Future<String> uploadAvatar(List<int> bytes, String filename) async {
    final response = await ApiClient.instance.upload(
      '/profile/avatar',
      bytes,
      filename,
    );
    final url = response.data['data']['url'].toString();
    final user = _user;
    if (user != null) {
      _user = AuthUser(
        id: user.id,
        email: user.email,
        emailConfirmedAt: user.emailConfirmedAt,
        userMetadata: {...user.userMetadata, 'avatar_url': url},
      );
      _events.add(AuthChangeEvent(AuthSession(_user!)));
    }
    return url;
  }

  List<String> get permissions => List<String>.from(
    _user?.userMetadata['permissions'] as List? ?? const [],
  );
  bool hasPermission(String permission) =>
      permissions.contains('*') || permissions.contains(permission);
  bool get isLoggedIn => _token != null && _user != null;
  Stream<AuthChangeEvent> get onAuthChange => _events.stream;

  Future<void> init() async {
    _token = await _storage.read(key: 'api_token');
    ApiClient.instance.tokenProvider = () => _token;
    if (_token == null) return;
    try {
      final response = await ApiClient.instance.get('/auth/me');
      _user = _parseUser(response.data);
      if (_user == null || _user!.emailConfirmedAt == null) {
        await _clear();
        return;
      }
      _events.add(AuthChangeEvent(AuthSession(_user!)));
    } catch (_) {
      await _clear();
    }
  }

  Future<AuthResponse> signIn(String email, String password) async {
    final response = await ApiClient.instance.post(
      '/auth/login',
      authenticated: false,
      maxRetries: 0,
      body: {
        'email': email.trim(),
        'password': password,
        'device_name': 'flutter',
      },
    );
    await _accept(response.data);
    return AuthResponse(_user);
  }

  Future<AuthResponse> signUp(
    String email,
    String password,
    Map<String, dynamic> metadata,
  ) async {
    final response = await ApiClient.instance.post(
      '/auth/register',
      authenticated: false,
      maxRetries: 0,
      body: {
        'email': email.trim(),
        'password': password,
        'password_confirmation': password,
        'name': metadata['full_name'] ?? '',
        'phone': metadata['phone'],
        'academic_year': metadata['academic_year'],
      },
    );
    return AuthResponse(_parseUser(response.data));
  }

  Future<OtpDispatch> sendOtp(String email, {String purpose = 'login'}) async {
    final response = await ApiClient.instance.post(
      '/auth/otp/send',
      authenticated: false,
      maxRetries: 0,
      body: {'email': email.trim(), 'purpose': purpose},
    );
    return OtpDispatch.fromBody(response.data);
  }

  Future<AuthResponse> verifyOTP({
    required String email,
    required String token,
    String purpose = 'email_verification',
  }) async {
    final response = await ApiClient.instance.post(
      '/auth/otp/verify',
      authenticated: false,
      maxRetries: 0,
      body: {
        'email': email.trim(),
        'code': token,
        'purpose': purpose,
        'device_name': 'flutter',
      },
    );
    await _accept(response.data);
    return AuthResponse(_user);
  }

  Future<bool> emailExists(String email) async {
    final response = await ApiClient.instance.get(
      '/auth/email-exists',
      authenticated: false,
      maxRetries: 0,
      query: {'email': email.trim()},
    );
    return response.data['data']['exists'] == true;
  }

  Future<OtpDispatch> resetPasswordForEmail(String email) async {
    final response = await ApiClient.instance.post(
      '/auth/forgot-password',
      authenticated: false,
      maxRetries: 0,
      body: {'email': email.trim()},
    );
    return OtpDispatch.fromBody(response.data);
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    await ApiClient.instance.post(
      '/auth/password/reset',
      authenticated: false,
      maxRetries: 0,
      body: {
        'email': email.trim(),
        'code': code,
        'password': password,
        'password_confirmation': password,
      },
    );
  }

  Future<void> updateStudentProfile({
    required String fullName,
    required String phone,
    required String university,
    required String academicYear,
    required String examNumber,
  }) async {
    final response = await ApiClient.instance.put(
      '/auth/profile',
      body: {
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'university': university.trim(),
        'academic_year': academicYear,
        'exam_number': examNumber.trim(),
      },
    );
    final updated = _parseUser(response.data);
    if (updated == null) {
      throw const ApiException(500, 'تعذر تحديث الملف الشخصي.');
    }
    _user = updated;
    _events.add(AuthChangeEvent(AuthSession(updated)));
  }

  Future<bool> signInWithGoogle() async {
    throw const ApiException(501, 'تسجيل Google يحتاج إعداد OAuth في Laravel.');
  }

  Future<void> signOut() async {
    try {
      await FcmTokenService.unregisterCurrentDevice();
      if (_token != null) await ApiClient.instance.post('/auth/logout');
    } finally {
      await AppDatabase.clearAllLocalData();
      await CacheManager.instance.invalidateAll();
      await PhotoService.clearAllLocalPhotos();
      await _clear();
    }
  }

  Future<void> _accept(dynamic body) async {
    final data = body is Map ? body['data'] : null;
    final token = data is Map ? data['token']?.toString() : null;
    final user = _parseUser(body);
    if (token == null ||
        token.isEmpty ||
        user == null ||
        user.emailConfirmedAt == null) {
      throw const ApiException(401, 'تعذر إنشاء جلسة آمنة.');
    }
    if (_user != null && _user!.id != user.id) {
      await AppDatabase.clearAllLocalData();
      await CacheManager.instance.invalidateAll();
      await PhotoService.clearAllLocalPhotos();
    }
    _token = token;
    _user = user;
    await _storage.write(key: 'api_token', value: _token);
    final expiresAt = data is Map ? data['token_expires_at']?.toString() : null;
    if (expiresAt != null) {
      await _storage.write(key: 'api_token_expires_at', value: expiresAt);
    }
    _events.add(AuthChangeEvent(AuthSession(_user!)));
    try {
      await FcmTokenService.init(authenticated: true);
    } catch (_) {}
  }

  AuthUser? _parseUser(dynamic body) {
    final raw = body is Map ? (body['data']?['user'] ?? body['user']) : null;
    return raw is Map
        ? AuthUser.fromJson(Map<String, dynamic>.from(raw))
        : null;
  }

  Future<void> _clear() async {
    _token = null;
    _user = null;
    await _storage.delete(key: 'api_token');
    await _storage.delete(key: 'api_token_expires_at');
    _events.add(const AuthChangeEvent(null));
  }
}
