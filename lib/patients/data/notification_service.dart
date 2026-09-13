import 'package:studentry/main.dart';
import 'package:studentry/patients/data/patient_data.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/student/data/subject_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static const String _configuredTimeZone = String.fromEnvironment(
    'APP_TIMEZONE',
    defaultValue: 'Asia/Damascus',
  );
  static const MethodChannel _settingsChannel = MethodChannel(
    'io.studentry.app/settings',
  );
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _permissionsConfigured = false;

  static bool get supportsExactAlarmPermission =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> init({bool requestPermissions = true}) async {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation(_configuredTimeZone));
      } catch (_) {
        // A bad build-time value must not disable notifications entirely.
        tz.setLocalLocation(tz.UTC);
      }

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
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'appointment_channel',
          'مواعيد العيادة',
          description: 'ملخص مواعيد اليوم وتنبيه قبل الموعد بنصف ساعة',
          importance: Importance.max,
        ),
      );
      await androidPlugin?.requestNotificationsPermission();
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

  static Future<bool> exactAlarmsEnabled() async {
    if (!supportsExactAlarmPermission) return true;
    try {
      await init(requestPermissions: false);
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await androidPlugin?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestExactAlarmPermission() async {
    if (!supportsExactAlarmPermission) return true;
    try {
      await init(requestPermissions: false);
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestExactAlarmsPermission();
      return exactAlarmsEnabled();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openExactAlarmSettings() async {
    if (!supportsExactAlarmPermission) return false;
    try {
      return await _settingsChannel.invokeMethod<bool>(
            'openExactAlarmSettings',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static AndroidNotificationDetails _appointmentDetails() =>
      AndroidNotificationDetails(
        'appointment_channel',
        'مواعيد العيادة',
        channelDescription: 'إشعارات تذكير بالمواعيد',
        importance: Importance.max,
        priority: Priority.max,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500]),
        playSound: true,
      );

  static const AndroidNotificationDetails _campaignDetails =
      AndroidNotificationDetails(
        'studentry_campaigns',
        'إشعارات Studentry',
        channelDescription:
            'العروض وتحديثات الطلبات والإشعارات الأكاديمية المرسلة من الإدارة',
        importance: Importance.high,
        priority: Priority.high,
      );

  static const AndroidNotificationDetails _generalDetails =
      AndroidNotificationDetails(
        'studentry_general',
        'إشعارات التطبيق',
        channelDescription: 'الإشعارات المحلية العامة للتطبيق',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      await init();
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: _generalDetails,
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }

  static Future<void> showCampaignNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await init();
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: _campaignDetails,
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (_) {}
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
    String? payload,
    bool appointmentReminder = true,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    try {
      // Appointment reminders must work even when Firebase cannot start (for
      // example while the device is offline). Local scheduling owns its own
      // notification permission instead of depending on the FCM bootstrap.
      await init();
      final location = tz.local;
      final scheduledDate = tz.TZDateTime.from(dateTime, location);
      final exactEnabled = await exactAlarmsEnabled();
      final mode = exactEnabled
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
      try {
        await _zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          mode: mode,
          payload: payload,
          appointmentReminder: appointmentReminder,
          matchDateTimeComponents: matchDateTimeComponents,
        );
      } catch (_) {
        if (mode == AndroidScheduleMode.exactAllowWhileIdle) {
          await _zonedSchedule(
            id: id,
            title: title,
            body: body,
            scheduledDate: scheduledDate,
            mode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: payload,
            appointmentReminder: appointmentReminder,
            matchDateTimeComponents: matchDateTimeComponents,
          );
        }
      }
    } catch (_) {}
  }

  static Future<void> _zonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required AndroidScheduleMode mode,
    String? payload,
    required bool appointmentReminder,
    DateTimeComponents? matchDateTimeComponents,
  }) => _plugin.zonedSchedule(
    id: id,
    title: title,
    body: body,
    scheduledDate: scheduledDate,
    notificationDetails: NotificationDetails(
      android: appointmentReminder ? _appointmentDetails() : _generalDetails,
      iOS: const DarwinNotificationDetails(),
    ),
    androidScheduleMode: mode,
    payload: payload,
    matchDateTimeComponents: matchDateTimeComponents,
  );

  static int _stableId(String value) {
    var hash = 0x811C9DC5;
    for (final codeUnit in value.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  static int _notificationId(Appointment appointment) =>
      _stableId('appointment:${appointment.id}');

  static String _doctorName() {
    final name = AuthService().fullName?.trim();
    return name == null || name.isEmpty ? 'الطبيب' : 'د. $name';
  }

  static Future<void> _scheduleAppointment(Appointment a) async {
    final parts = a.time.split(':');
    if (parts.length != 2) {
      return;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
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
    if (!appointmentTime.isAfter(now)) {
      return;
    }

    final reminderTime = appointmentTime.subtract(const Duration(minutes: 30));
    final id = _notificationId(a);

    if (reminderTime.isAfter(now)) {
      await scheduleNotification(
        id: id,
        title: 'تذكير بموعد مريض',
        body:
            '${_doctorName()}، موعد المريض ${a.patientName} الساعة ${a.time} بعد نصف ساعة.',
        dateTime: reminderTime,
        payload: 'appointment:${a.id}',
      );
    }
  }

  static Future<void> cancelAppointmentNotification(Appointment a) {
    return cancelNotification(_notificationId(a));
  }

  static Future<void> onAppointmentAdded(Appointment a) async {
    await cancelNotification(_notificationId(a));
    await _scheduleAppointment(a);
  }

  static Future<void> scheduleAllAppointments(
    List<Appointment> appointments,
  ) async {
    try {
      await init();
      final pending = await _plugin.pendingNotificationRequests();
      for (final notification in pending) {
        final payload = notification.payload ?? '';
        if (payload.startsWith('appointment:') ||
            payload.startsWith('appointments-day:')) {
          await _plugin.cancel(id: notification.id);
        }
      }

      final upcoming =
          appointments
              .where(
                (appointment) =>
                    appointment.appointmentDateTime.isAfter(DateTime.now()),
              )
              .toList()
            ..sort(
              (first, second) => first.appointmentDateTime.compareTo(
                second.appointmentDateTime,
              ),
            );
      for (final appointment in upcoming) {
        await _scheduleAppointment(appointment);
      }
      await _scheduleDailySummaries(upcoming);
    } catch (_) {
      // A notification permission/plugin failure must never block local data.
    }
  }

  static Future<void> _scheduleDailySummaries(
    List<Appointment> appointments,
  ) async {
    final byDay = <String, List<Appointment>>{};
    for (final appointment in appointments) {
      final day = appointment.appointmentDateTime;
      final key =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      byDay.putIfAbsent(key, () => []).add(appointment);
    }

    final now = DateTime.now();
    for (final entry in byDay.entries) {
      final first = entry.value.first.appointmentDateTime;
      final summaryTime = DateTime(first.year, first.month, first.day, 7);
      if (!summaryTime.isAfter(now)) continue;
      final visible = entry.value
          .take(5)
          .map(
            (appointment) => '${appointment.patientName} ${appointment.time}',
          )
          .join('، ');
      final remaining = entry.value.length - 5;
      final suffix = remaining > 0 ? '، و$remaining مواعيد إضافية' : '';
      await scheduleNotification(
        id: _stableId('appointments-day:${entry.key}'),
        title: 'مواعيد اليوم — ${_doctorName()}',
        body: '$visible$suffix',
        dateTime: summaryTime,
        payload: 'appointments-day:${entry.key}',
      );
    }
  }

  static Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id: id);
  }

  static void _onNotificationTap(NotificationResponse response) {
    if (response.payload == 'cart') {
      navigatorKey.currentState?.pushNamed('/cart');
    } else if (response.payload?.startsWith('/') == true) {
      navigatorKey.currentState?.pushNamed(response.payload!);
    }
  }

  static Future<void> showCartReminder() async {
    final id = 'cart_reminder'.hashCode;
    try {
      await init();
      await _plugin.show(
        id: id,
        title: 'لديك منتجات في السلة',
        body: 'لم تقم بإتمام الطلب بعد. اضغط هنا للمتابعة',
        notificationDetails: NotificationDetails(
          android: _generalDetails,
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

  // ─── Weekly lecture reminders (15 minutes before) ───

  static const int lectureReminderMinutes = 15;

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
    await init(requestPermissions: false);
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      if ((notification.payload ?? '').startsWith('lecture:')) {
        await _plugin.cancel(id: notification.id);
      }
    }
    for (final e in enrollments) {
      for (final day in e.scheduleDays) {
        for (final timeStr in e.scheduleTimes) {
          await _scheduleSingleLecture(e.name, e.subjectId, day, timeStr);
        }
      }
    }
  }

  static Future<void> _scheduleSingleLecture(
    String subjName,
    String subjId,
    String day,
    String timeStr,
  ) async {
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
    final reminderTime = lectureDt.subtract(
      const Duration(minutes: lectureReminderMinutes),
    );

    if (reminderTime.isBefore(now)) {
      // If reminder already passed for this week, try next week
      final nextWeek = lectureDt.add(const Duration(days: 7));
      final nextReminder = nextWeek.subtract(
        const Duration(minutes: lectureReminderMinutes),
      );
      await _scheduleLectureNotification(
        subjName,
        subjId,
        day,
        timeStr,
        nextReminder,
      );
    } else {
      await _scheduleLectureNotification(
        subjName,
        subjId,
        day,
        timeStr,
        reminderTime,
      );
    }
  }

  static Future<void> _scheduleLectureNotification(
    String subjName,
    String subjId,
    String day,
    String timeStr,
    DateTime dateTime,
  ) async {
    final key = 'lecture:$subjId:$day:$timeStr';
    final id = _stableId(key);
    if (dateTime.isBefore(DateTime.now())) return;
    await scheduleNotification(
      id: id,
      title: 'محاضرة بعد 15 دقيقة',
      body: 'تبدأ محاضرة $subjName بعد 15 دقيقة',
      dateTime: dateTime,
      payload: key,
      appointmentReminder: false,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }
}
