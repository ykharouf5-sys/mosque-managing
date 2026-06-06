import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:vibration/vibration.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    
    // Android initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    // iOS initialization settings
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combined initialization settings
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize the plugin
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions for iOS
    await _requestIOSPermissions();

    // Create notification channel for Android
    await _createAndroidNotificationChannel();

    _initialized = true;
    print('✅ Local Notification Service initialized');
  }

  /// Request permissions for iOS
  Future<void> _requestIOSPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  /// Create Android notification channels
  Future<void> _createAndroidNotificationChannel() async {
    // Chat messages channel
    final AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
      'chat_messages_channel',
      'رسائل الدردشة',
      description: 'إشعارات الرسائل الجديدة في الدردشة',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(const [0, 500, 200, 500]), // Long double pulse
    );

    // Prayer times channel
    final AndroidNotificationChannel prayerChannel = AndroidNotificationChannel(
      'prayer_times_channel',
      'أوقات الصلاة',
      description: 'تذكير بأوقات الصلوات الخمس',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(const [0, 1000, 500, 1000, 500, 1000]), // Triple long pulse
      // sound: RawResourceAndroidNotificationSound('azan'), // Removed if no azan file
    );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    await androidPlugin?.createNotificationChannel(chatChannel);
    await androidPlugin?.createNotificationChannel(prayerChannel);
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('📱 Notification tapped: ${response.payload}');
    // TODO: Navigate to chat screen based on payload
    // You can parse the payload to get conversation ID and navigate
  }

  /// Show a simple notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'chat_messages_channel',
      'رسائل الدردشة',
      channelDescription: 'إشعارات الرسائل الجديدة في الدردشة',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/launcher_icon',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    // Explicitly vibrate the device
    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(pattern: [0, 500, 200, 500]);
      }
    } catch (e) {
      print('Vibration error: $e');
    }

    print('📬 Notification shown: $title');
  }

  /// Show notification for new chat message
  Future<void> showChatMessageNotification({
    required String senderName,
    required String messageText,
    required String conversationId,
  }) async {
    final int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await showNotification(
      id: notificationId,
      title: 'رسالة جديدة من $senderName',
      body: messageText,
      payload: 'chat:$conversationId',
    );
  }

  /// Schedule a notification for a specific time
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'chat_messages_channel',
      'رسائل الدردشة',
      channelDescription: 'إشعارات الرسائل الجديدة في الدردشة',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    print('⏰ Notification scheduled for: $scheduledTime');
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Get list of pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }
  
  // ---------------------------------------------------------------------------
  // Prayer Notifications
  // ---------------------------------------------------------------------------
  
  /// Schedule notifications for prayer times
  Future<void> schedulePrayerNotifications(Map<String, DateTime> prayerTimes) async {
    print('🕌 Scheduling prayer notifications...');
    
    // Cancel existing prayer notifications first
    await cancelPrayerNotifications();

    final prayerNames = {
      'Fajr': 'الفجر',
      'Dhuhr': 'الظهر',
      'Asr': 'العصر',
      'Maghrib': 'المغرب',
      'Isha': 'العشاء',
    };

    int notificationId = 1000; // Start from 1000 for prayer notifications

    for (final entry in prayerTimes.entries) {
      final prayerKey = entry.key;
      final prayerTime = entry.value;
      final prayerNameAr = prayerNames[prayerKey] ?? prayerKey;

      // Only schedule if the time is in the future
      if (prayerTime.isAfter(DateTime.now())) {
        await _schedulePrayerNotification(
          id: notificationId++,
          prayerName: prayerNameAr,
          scheduledTime: prayerTime,
        );
      } else {
        print('⏭️ Skipping $prayerNameAr (time already passed)');
      }
    }

    print('✅ Prayer notifications scheduled successfully');
  }

  /// Schedule a single prayer notification
  Future<void> _schedulePrayerNotification({
    required int id,
    required String prayerName,
    required DateTime scheduledTime,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'prayer_times_channel',
      'أوقات الصلاة',
      channelDescription: 'تذكير بأوقات الصلوات الخمس',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/launcher_icon',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'azan.mp3', // Optional: custom sound file
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      'حان وقت صلاة $prayerName',
      'الصلاة خير من النوم 🕌',
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'prayer:$prayerName',
    );

    print('⏰ Scheduled notification for $prayerName at ${scheduledTime.hour}:${scheduledTime.minute}');
  }

  /// Cancel all prayer notifications (IDs 1000-1004)
  Future<void> cancelPrayerNotifications() async {
    for (int id = 1000; id < 1005; id++) {
      await _notificationsPlugin.cancel(id);
    }
    print('🗑️ Cancelled all prayer notifications');
  }
}
