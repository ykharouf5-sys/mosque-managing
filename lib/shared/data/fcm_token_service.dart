import 'dart:io';
import 'dart:async';

import 'package:studentry/patients/data/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'api_client.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class FcmTokenService {
  FcmTokenService._();
  static const _storage = FlutterSecureStorage();
  static const _deviceIdKey = 'aqua_device_id_v1';
  static bool _initialized = false;
  static bool _authenticated = false;
  static String? _registeredToken;
  static String? _registeringToken;
  static Future<void>? _registrationInFlight;
  static Timer? _retryTimer;
  static int _session = 0;
  static String? _accountId;
  static bool _watchingConnectivity = false;

  static void _onConnectivity() {
    if (_authenticated && ConnectivityService.isOnline.value) {
      unawaited(_refreshRegistration(_session));
    }
  }

  static Future<void> _refreshRegistration(int session) async {
    if (!_authenticated || session != _session) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (session == _session && token != null) await registerToken(token);
    } catch (_) {
      _scheduleRetry(session);
    }
  }

  static void _scheduleRetry(int session) {
    if (!_authenticated || session != _session) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 30), () {
      if (ConnectivityService.isOnline.value) {
        unawaited(_refreshRegistration(session));
      } else {
        _scheduleRetry(session);
      }
    });
  }

  static Future<void> init({required bool authenticated}) async {
    final accountId = authenticated ? AuthService().currentUser?.id : null;
    if (_accountId != accountId || _authenticated != authenticated) {
      _session++;
      _accountId = accountId;
      _registeredToken = null;
      _registeringToken = null;
      _registrationInFlight = null;
      _retryTimer?.cancel();
    }
    _authenticated = authenticated;
    if (!_watchingConnectivity) {
      ConnectivityService.isOnline.addListener(_onConnectivity);
      _watchingConnectivity = true;
    }
    if (!_initialized) {
      await NotificationService.init();
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
      FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) => registerToken(token),
      );
      FirebaseMessaging.onMessage.listen((message) async {
        final notification = message.notification;
        if (notification != null && !kIsWeb && Platform.isAndroid) {
          await NotificationService.init();
          await NotificationService.showCampaignNotification(
            id:
                message.messageId?.hashCode ??
                DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
            title: notification.title ?? '',
            body: notification.body ?? '',
            payload: message.data['action_route']?.toString(),
          );
        }
      });
      _initialized = true;
    }
    if (authenticated) {
      await _refreshRegistration(_session);
    } else {
      // Invalidate any token left by an expired/offline session so a signed-out
      // device cannot keep receiving account-scoped notifications.
      await FirebaseMessaging.instance.deleteToken();
    }
  }

  static Future<void> registerToken(String token) async {
    if (!_authenticated) return;
    if (_registeredToken == token) return;
    if (_registeringToken == token && _registrationInFlight != null) {
      return _registrationInFlight!;
    }
    late final Future<void> registration;
    registration = _registerToken(token).whenComplete(() {
      if (identical(_registrationInFlight, registration)) {
        _registrationInFlight = null;
        _registeringToken = null;
      }
    });
    _registeringToken = token;
    _registrationInFlight = registration;
    return registration;
  }

  static Future<void> _registerToken(String token) async {
    final session = _session;
    try {
      final deviceId = await _deviceId();
      if (!_authenticated || session != _session) return;
      await ApiClient.instance.post(
        '/devices/fcm-token',
        body: {
          'token': token,
          'device_id': deviceId,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
        maxRetries: 1,
      );
      if (_authenticated && session == _session) {
        _registeredToken = token;
        _retryTimer?.cancel();
      }
    } catch (_) {
      _scheduleRetry(session);
    }
  }

  static Future<void> unregisterCurrentDevice() async {
    _session++;
    _authenticated = false;
    _accountId = null;
    _registeredToken = null;
    _registeringToken = null;
    _registrationInFlight = null;
    _retryTimer?.cancel();
    if (!_initialized) return;
    final deviceId = await _deviceId();
    try {
      await ApiClient.instance.delete(
        '/devices/fcm-token',
        headers: {'X-Device-Id': deviceId},
      );
    } catch (_) {}
    _authenticated = false;
    _registeredToken = null;
    _registeringToken = null;
    await FirebaseMessaging.instance.deleteToken();
  }

  static Future<String> _deviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null) return existing;
    final created = const Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: created);
    return created;
  }
}
