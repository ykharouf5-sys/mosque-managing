import 'dart:io';

import 'package:dentalcare/patients/data/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'api_client.dart';

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

  static Future<void> init({required bool authenticated}) async {
    _authenticated = authenticated;
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
          await NotificationService.showNow(
            id:
                message.messageId?.hashCode ??
                DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
            title: notification.title ?? '',
            body: notification.body ?? '',
          );
        }
      });
      _initialized = true;
    }
    if (authenticated) {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await registerToken(token);
    }
  }

  static Future<void> registerToken(String token) async {
    if (!_authenticated) return;
    final deviceId = await _deviceId();
    try {
      await ApiClient.instance.post(
        '/devices/fcm-token',
        body: {
          'token': token,
          'device_id': deviceId,
          'platform': Platform.isIOS ? 'ios' : 'android',
        },
        maxRetries: 1,
      );
    } catch (error) {
      debugPrint('FCM token registration failed: $error');
    }
  }

  static Future<void> unregisterCurrentDevice() async {
    if (!_initialized) return;
    final deviceId = await _deviceId();
    try {
      await ApiClient.instance.delete(
        '/devices/fcm-token',
        headers: {'X-Device-Id': deviceId},
      );
    } catch (_) {}
    _authenticated = false;
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
