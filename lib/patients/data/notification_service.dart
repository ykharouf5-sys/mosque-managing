import 'package:studentry/main.dart';
import 'package:studentry/patients/data/patient_data.dart';
import 'package:studentry/student/data/subject_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _permissionsConfigured = false;

  static Future<void> init({bool requestPermissions = true}) async {
    if (!_initialized) {
      tz_data.initializeTimeZones();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      final settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      _initialized = true;
    }

    if (!requestPermissions || _permissionsConfigured) return;

    // Request permissions for Android 13+ and Android 12+
    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'studentry_campaigns',
          'إشعارات Studentry',
          description: 'العروض وتحديثات الطلبات والإشعارات الأكاديمية',
          importance: Importance.high,
        ),
      );
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      _permissionsConfigured = true;
    } catch (_) {}
  }

  static AndroidNotificationDetails _details() => AndroidNotificationDetails(
    'appointment_channel',
    'مواعيد العيادة',
    channelDescription: 'إشعارات تذكير بالمواعيد',
    importance: Importance.max,
    priority: Priority.max,
    enableVibration: true,
    vibrationPattern: Int64List.fromList([0, 500]),
    playSound: true,
  );

  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    debugPrint('🔔 showNow: id=$id title=$title');
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: _details(),
          iOS: const DarwinNotificationDetails(),
        ),
      );
      debugPrint('✅ showNow done');
    } catch (e) {
      debugPrint('❌ showNow error: $e');
    }
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    debugPrint('🔔 scheduleNotification: id=$id title=$title at $dateTime');
    try {
      final location = tz.local;
      final scheduledDate = tz.TZDateTime.from(dateTime, location);
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: NotificationDetails(
          android: _details(),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.alarmClock,
      );
      debugPrint('✅ scheduleNotification done');
    } catch (e) {
      debugPrint('❌ scheduleNotification error: $e');
    }
  }

  static int _notificationId(Appointment a) =>
      '${a.patientId}_${a.time}'.hashCode;

  static void _scheduleAppointment(Appointment a) {
    final parts = a.time.split(':');
    if (parts.length != 2) {
      debugPrint('⚠️ _scheduleAppointment: invalid time format "${a.time}"');
      return;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      debugPrint('⚠️ _scheduleAppointment: invalid time parts "${a.time}"');
      return;
    }

    final now = DateTime.now();
    final appointmentTime = DateTime(
      a.date.year,
      a.date.month,
      a.date.day,
      hour,
      minute,
    );
    debugPrint(
      '🔔 _scheduleAppointment: ${a.patientName} at $appointmentTime (now=$now)',
    );
    if (appointmentTime.isBefore(now)) {
      debugPrint('⚠️ _scheduleAppointment: appointment already passed');
      return;
    }

    final reminderTime = appointmentTime.subtract(const Duration(minutes: 30));
    final id = _notificationId(a);

    if (reminderTime.isBefore(now)) {
      debugPrint(
        '🔔 _scheduleAppointment: showing now (reminder was $reminderTime)',
      );
      showNow(
        id: id,
        title: 'موعد الآن',
        body: 'لديك موعد مع ${a.patientName} - ${a.treatment}',
      );
    } else {
      debugPrint('🔔 _scheduleAppointment: scheduling for $reminderTime');
      scheduleNotification(
        id: id,
        title: 'تذكير بموعد',
        body: 'لديك موعد مع ${a.patientName} - ${a.treatment} بعد 30 دقيقة',
        dateTime: reminderTime,
      );
    }
  }

  static void cancelAppointmentNotification(Appointment a) {
    cancelNotification(_notificationId(a));
  }

  static void onAppointmentAdded(Appointment a) {
    cancelNotification(_notificationId(a));
    _scheduleAppointment(a);
  }

  static void scheduleAllAppointments(List<Appointment> appointments) {
    for (final a in appointments) {
      _scheduleAppointment(a);
    }
  }

  static Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id: id);
  }

  static void _onNotificationTap(NotificationResponse response) {
    if (response.payload == 'cart') {
      navigatorKey.currentState?.pushNamed('/cart');
    }
  }

  static Future<void> showCartReminder() async {
    final id = 'cart_reminder'.hashCode;
    await showNow(
      id: id,
      title: 'لديك منتجات في السلة',
      body: 'لم تقم بإتمام الطلب بعد. اضغط هنا للمتابعة',
    );
    // Re-schedule with payload by cancelling and re-showing with schedule
    try {
      await _plugin.show(
        id: id,
        title: 'لديك منتجات في السلة',
        body: 'لم تقم بإتمام الطلب بعد. اضغط هنا للمتابعة',
        notificationDetails: NotificationDetails(
          android: _details(),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: 'cart',
      );
    } catch (_) {}
  }

  static Future<void> cancelAll() async {
    await init(requestPermissions: false);
    await _plugin.cancelAll();
  }

  // ─── Lecture reminders (10 minutes before) ───

  static const Map<String, int> _arabicDays = {
    'الأحد': DateTime.sunday,
    'الإثنين': DateTime.monday,
    'الثلاثاء': DateTime.tuesday,
    'الأربعاء': DateTime.wednesday,
    'الخميس': DateTime.thursday,
  };

  static Future<void> scheduleLectureNotifications(
    List<StudentSubject> enrollments,
  ) async {
    // Cancel old lecture notifications
    await cancelAll();
    // Re-schedule for all
    for (final e in enrollments) {
      for (final day in e.scheduleDays) {
        for (final timeStr in e.scheduleTimes) {
          _scheduleSingleLecture(e.name, e.subjectId, day, timeStr);
        }
      }
    }
  }

  static void _scheduleSingleLecture(
    String subjName,
    String subjId,
    String day,
    String timeStr,
  ) {
    final dayNum = _arabicDays[day];
    if (dayNum == null) return;
    final parts = timeStr.split(' - ');
    final startParts = (parts.isNotEmpty ? parts[0] : timeStr).split(':');
    if (startParts.length < 2) return;
    final hour = int.tryParse(startParts[0]);
    final minute = int.tryParse(startParts[1].replaceAll(RegExp(r'\D'), ''));
    if (hour == null || minute == null) return;

    final now = DateTime.now();
    final lectureToday = DateTime(now.year, now.month, now.day, hour, minute);
    int daysUntil = (dayNum - now.weekday) % 7;
    if (daysUntil == 0 && lectureToday.isBefore(now)) daysUntil = 7;
    final lectureDate = now.add(Duration(days: daysUntil));
    final lectureDt = DateTime(
      lectureDate.year,
      lectureDate.month,
      lectureDate.day,
      hour,
      minute,
    );
    final reminderTime = lectureDt.subtract(const Duration(minutes: 10));

    if (reminderTime.isBefore(now)) {
      // If reminder already passed for this week, try next week
      final nextWeek = lectureDt.add(const Duration(days: 7));
      final nextReminder = nextWeek.subtract(const Duration(minutes: 10));
      _scheduleNotification(subjName, nextReminder);
    } else {
      _scheduleNotification(subjName, reminderTime);
    }
  }

  static void _scheduleNotification(String subjName, DateTime dateTime) {
    final id = dateTime.hashCode;
    if (dateTime.isBefore(DateTime.now())) return;
    scheduleNotification(
      id: id,
      title: 'محاضرة بعد 10 دقائق',
      body: 'تبدأ محاضرة $subjName بعد 10 دقائق',
      dateTime: dateTime,
    );
  }
}
