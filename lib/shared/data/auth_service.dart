import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'account_data_lifecycle.dart';
import 'api_client.dart';
import 'api_request_queue.dart';
import 'fcm_token_service.dart';

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

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim();
    if (id == null || id.isEmpty) {
      throw const FormatException('The authenticated user has no identifier.');
    }
    final rawClinicId = json['clinic_id']?.toString().trim();
    final clinicId = rawClinicId == null || rawClinicId.isEmpty
        ? null
        : rawClinicId;
    final rawMembershipStatus = json['membership_status']
        ?.toString()
        .trim()
        .toLowerCase();
    final membershipStatus =
        rawMembershipStatus == null || rawMembershipStatus.isEmpty
        ? (clinicId == null ? 'pending' : 'active')
        : rawMembershipStatus;
    final rawScopeVersion = json['clinical_scope_version'];
    final clinicalScopeVersion = rawScopeVersion is num
        ? rawScopeVersion.toInt()
        : int.tryParse(rawScopeVersion?.toString() ?? '') ?? 0;

    return AuthUser(
      id: id,
      email: json['email']?.toString(),
      userMetadata: {
        'role': json['role'],
        'permissions': List<String>.from(
          json['permissions'] as List? ?? const [],
        ),
        'clinic_id': clinicId,
        'membership_status': membershipStatus,
        'clinical_scope_version': clinicalScopeVersion,
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    ...userMetadata,
    'email_confirmed_at': emailConfirmedAt?.toUtc().toIso8601String(),
  };

  String? get clinicId {
    final value = userMetadata['clinic_id']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  String get role => userMetadata['role']?.toString() ?? 'student';

  List<String> get permissions =>
      List<String>.from(userMetadata['permissions'] as List? ?? const []);

  String get membershipStatus {
    final value = userMetadata['membership_status']
        ?.toString()
        .trim()
        .toLowerCase();
    if (value == null || value.isEmpty) {
      return clinicId == null ? 'pending' : 'active';
    }
    return value;
  }

  int get clinicalScopeVersion {
    final value = userMetadata['clinical_scope_version'];
    return value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool get profileCompleted => userMetadata['profile_completed'] == true;

  bool get hasActiveClinicalMembership =>
      membershipStatus == 'active' && clinicId != null;

  bool hasPermission(String permission) {
    if (_requiresClinicalMembership(permission) &&
        !hasActiveClinicalMembership) {
      return false;
    }
    return permissions.contains('*') || permissions.contains(permission);
  }

  static bool _requiresClinicalMembership(String permission) =>
      permission == 'sync.use' ||
      permission.startsWith('patients.') ||
      permission.startsWith('appointments.') ||
      permission.startsWith('payments.');
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
  AuthService._() {
    ApiClient.instance.sessionGenerationProvider = () => _sessionGeneration;
  }
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'api_token';
  static const _tokenExpiresAtKey = 'api_token_expires_at';
  static const _cachedUserKey = 'api_cached_user';
  final _events = StreamController<AuthChangeEvent>.broadcast();
  Future<void> _sessionMutation = Future<void>.value();
  Timer? _expiryTimer;
  int _sessionGeneration = 0;
  String? _token;
  DateTime? _tokenExpiresAt;
  AuthUser? _user;

  int get sessionGeneration => _sessionGeneration;

  AuthUser? get currentUser => _user;
  String? get userId => _user?.id;
  String? get email => _user?.email;
  String? get clinicId => _user?.clinicId;
  String? get role => _user?.role;
  String get membershipStatus => _user?.membershipStatus ?? 'pending';
  int get clinicalScopeVersion => _user?.clinicalScopeVersion ?? 0;
  bool get hasActiveClinicalMembership =>
      _user?.hasActiveClinicalMembership ?? false;
  String? get fullName => _user?.userMetadata['full_name'] as String?;
  String? get phone => _user?.userMetadata['phone'] as String?;
  String? get academicYear => _user?.userMetadata['academic_year'] as String?;
  String? get university => _user?.userMetadata['university'] as String?;
  String? get examNumber => _user?.userMetadata['exam_number'] as String?;
  bool get profileCompleted => _user?.profileCompleted ?? false;
  String? get avatarUrl => _user?.userMetadata['avatar_url'] as String?;

  Future<String> uploadAvatar(List<int> bytes, String filename) async {
    final generation = _sessionGeneration;
    final response = await ApiClient.instance.upload(
      '/profile/avatar',
      bytes,
      filename,
    );
    final url = response.data['data']['url'].toString();
    await _runSessionMutation(() async {
      if (generation != _sessionGeneration) {
        throw const StaleSessionException();
      }
      final user = _user;
      if (user == null) throw const StaleSessionException();
      final updated = AuthUser(
        id: user.id,
        email: user.email,
        emailConfirmedAt: user.emailConfirmedAt,
        userMetadata: {...user.userMetadata, 'avatar_url': url},
      );
      await _setCurrentUser(updated);
    });
    return url;
  }

  List<String> get permissions => _user?.permissions ?? const [];
  bool hasPermission(String permission) =>
      _user?.hasPermission(permission) ?? false;
  bool get isLoggedIn =>
      _token != null &&
      _user != null &&
      _tokenExpiresAt != null &&
      _tokenExpiresAt!.isAfter(DateTime.now().toUtc());
  Stream<AuthChangeEvent> get onAuthChange => _events.stream;

  Future<T> _runSessionMutation<T>(Future<T> Function() action) {
    final result = _sessionMutation.then((_) => action());
    _sessionMutation = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  Future<void> init() async {
    _token = await _storage.read(key: _tokenKey);
    ApiClient.instance.tokenProvider = () => _token;
    if (_token == null) return;
    if (!await _hasUnexpiredStoredToken()) {
      await _clearAndPurge();
      return;
    }
    try {
      final response = await ApiClient.instance.get('/auth/me', maxRetries: 0);
      final user = _parseUser(response.data);
      if (user == null || user.emailConfirmedAt == null) {
        await _clearAndPurge();
        return;
      }
      _sessionGeneration++;
      await _activateUser(user);
      await _setCurrentUser(user);
    } catch (error) {
      if (_isRejectedSession(error) || !await _restoreCachedUser()) {
        await _clearAndPurge();
      }
    }
  }

  Future<AuthUser> refreshCurrentUser() async {
    if (_token == null) {
      throw const ApiException(401, 'لا توجد جلسة مسجلة لتحديثها.');
    }
    final generation = _sessionGeneration;
    late final ApiResult response;
    try {
      response = await ApiClient.instance.get('/auth/me', maxRetries: 0);
    } catch (error) {
      if (_isRejectedSession(error)) await _clearAndPurge();
      rethrow;
    }
    final updated = _parseUser(response.data);
    if (updated == null || updated.emailConfirmedAt == null) {
      throw const ApiException(401, 'تعذر تحديث بيانات الجلسة.');
    }
    await _runSessionMutation(() async {
      if (generation != _sessionGeneration) {
        throw const StaleSessionException();
      }
      _sessionGeneration++;
      await _activateUser(updated);
      await _setCurrentUser(updated);
    });
    return updated;
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
    final generation = _sessionGeneration;
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
    await _runSessionMutation(() async {
      if (generation != _sessionGeneration) {
        throw const StaleSessionException();
      }
      _sessionGeneration++;
      await _activateUser(updated);
      await _setCurrentUser(updated);
    });
  }

  Future<bool> signInWithGoogle() async {
    throw const ApiException(501, 'تسجيل Google يحتاج إعداد OAuth في Laravel.');
  }

  Future<void> signOut() => _runSessionMutation(_signOutUnlocked);

  Future<void> _signOutUnlocked() async {
    _sessionGeneration++;
    try {
      await FcmTokenService.unregisterCurrentDevice();
      if (_token != null) await ApiClient.instance.post('/auth/logout');
    } finally {
      try {
        await AccountDataLifecycle.clearAllUserData();
      } finally {
        await _clear();
      }
    }
  }

  Future<void> _accept(dynamic body) =>
      _runSessionMutation(() => _acceptUnlocked(body));

  Future<void> _acceptUnlocked(dynamic body) async {
    final data = body is Map ? body['data'] : null;
    final token = data is Map ? data['token']?.toString() : null;
    final expiresAt = data is Map ? data['token_expires_at']?.toString() : null;
    final tokenExpiry = DateTime.tryParse(expiresAt ?? '');
    final user = _parseUser(body);
    if (token == null ||
        token.isEmpty ||
        tokenExpiry == null ||
        !tokenExpiry.toUtc().isAfter(DateTime.now().toUtc()) ||
        user == null ||
        user.emailConfirmedAt == null) {
      throw const ApiException(401, 'تعذر إنشاء جلسة آمنة.');
    }
    _sessionGeneration++;
    await _activateUser(user);
    _token = token;
    await _storage.write(key: _tokenKey, value: _token);
    await _storage.write(
      key: _tokenExpiresAtKey,
      value: tokenExpiry.toUtc().toIso8601String(),
    );
    _tokenExpiresAt = tokenExpiry.toUtc();
    _scheduleExpiry(_tokenExpiresAt!);
    await _setCurrentUser(user);
    try {
      await FcmTokenService.init(authenticated: true);
    } catch (_) {}
  }

  Future<void> _activateUser(AuthUser user) async {
    final canRetainClinicalData =
        user.hasPermission('patients.read') &&
        user.hasPermission('appointments.read');
    await AccountDataLifecycle.activate(
      accountId: user.id,
      clinicalScopeVersion: user.clinicalScopeVersion > 0
          ? user.clinicalScopeVersion
          : 1,
      forceClinicalReset: !canRetainClinicalData,
    );
  }

  Future<void> invalidateRejectedSession() => _clearAndPurge();

  Future<void> _setCurrentUser(AuthUser user) async {
    _user = user;
    await _persistUser(user);
    _events.add(AuthChangeEvent(AuthSession(user)));
  }

  Future<void> _persistUser(AuthUser user) async {
    await _storage.write(key: _cachedUserKey, value: jsonEncode(user.toJson()));
  }

  Future<bool> _restoreCachedUser() async {
    try {
      final raw = await _storage.read(key: _cachedUserKey);
      if (raw == null || raw.isEmpty) return false;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final user = AuthUser.fromJson(Map<String, dynamic>.from(decoded));
      if (user.id.isEmpty || user.emailConfirmedAt == null) return false;
      _sessionGeneration++;
      await _activateUser(user);
      await _setCurrentUser(user);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hasUnexpiredStoredToken() async {
    final raw = await _storage.read(key: _tokenExpiresAtKey);
    final expiresAt = DateTime.tryParse(raw ?? '');
    if (expiresAt == null ||
        !expiresAt.toUtc().isAfter(DateTime.now().toUtc())) {
      return false;
    }
    _tokenExpiresAt = expiresAt.toUtc();
    _scheduleExpiry(_tokenExpiresAt!);
    return true;
  }

  void _scheduleExpiry(DateTime expiresAt) {
    _expiryTimer?.cancel();
    final remaining = expiresAt.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) {
      invalidateRejectedSession();
      return;
    }
    _expiryTimer = Timer(remaining, invalidateRejectedSession);
  }

  bool _isRejectedSession(Object error) =>
      error is ApiException &&
      (error.statusCode == 401 ||
          error.statusCode == 403 ||
          error.statusCode == 419);

  Future<void> _clearAndPurge() => _runSessionMutation(_clearAndPurgeUnlocked);

  Future<void> _clearAndPurgeUnlocked() async {
    _sessionGeneration++;
    try {
      try {
        await FcmTokenService.unregisterCurrentDevice();
      } catch (_) {}
      await AccountDataLifecycle.clearAllUserData();
    } finally {
      await _clear();
    }
  }

  AuthUser? _parseUser(dynamic body) {
    final raw = body is Map ? (body['data']?['user'] ?? body['user']) : null;
    return raw is Map
        ? AuthUser.fromJson(Map<String, dynamic>.from(raw))
        : null;
  }

  Future<void> _clear() async {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _token = null;
    _tokenExpiresAt = null;
    _user = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _tokenExpiresAtKey);
    await _storage.delete(key: _cachedUserKey);
    _events.add(const AuthChangeEvent(null));
  }
}
