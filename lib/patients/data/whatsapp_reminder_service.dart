import 'package:url_launcher/url_launcher.dart';

enum WhatsAppLaunchResult { opened, invalidPhone, unavailable }

class WhatsAppReminderService {
  static const String _defaultCountryCode = String.fromEnvironment(
    'DEFAULT_PHONE_COUNTRY_CODE',
    defaultValue: '963',
  );

  static String? normalizePhone(
    String value, {
    String countryCode = _defaultCountryCode,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    var digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    } else if (!trimmed.startsWith('+')) {
      if (digits.startsWith('0')) {
        digits = '$countryCode${digits.substring(1)}';
      } else if (!digits.startsWith(countryCode) && digits.length <= 10) {
        digits = '$countryCode$digits';
      }
    }

    if (digits.length < 8 || digits.length > 15) return null;
    return digits;
  }

  static String buildMessage({
    required String doctorName,
    required DateTime appointmentTime,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final appointmentDay = DateTime(
      appointmentTime.year,
      appointmentTime.month,
      appointmentTime.day,
    );
    final dayDifference = appointmentDay.difference(today).inDays;
    final dayLabel = switch (dayDifference) {
      0 => 'اليوم',
      1 => 'غداً',
      _ =>
        'بتاريخ ${appointmentTime.day.toString().padLeft(2, '0')}/'
            '${appointmentTime.month.toString().padLeft(2, '0')}/'
            '${appointmentTime.year}',
    };
    final time =
        '${appointmentTime.hour.toString().padLeft(2, '0')}:'
        '${appointmentTime.minute.toString().padLeft(2, '0')}';
    final clinic = doctorName.trim().isEmpty
        ? 'العيادة'
        : 'عيادة ${doctorName.trim()}';

    return 'مرحباً، تذكير بموعدك لدى $clinic $dayLabel الساعة $time. '
        'يرجى تأكيد الحضور، شكراً.';
  }

  static Uri? buildWebUri({required String phone, required String message}) {
    final normalized = normalizePhone(phone);
    if (normalized == null) return null;
    return Uri.https('wa.me', '/$normalized', <String, String>{
      'text': message,
    });
  }

  static Future<WhatsAppLaunchResult> openReminder({
    required String phone,
    required String message,
  }) async {
    final normalized = normalizePhone(phone);
    if (normalized == null) return WhatsAppLaunchResult.invalidPhone;

    final whatsappUri = Uri(
      scheme: 'whatsapp',
      host: 'send',
      queryParameters: <String, String>{'phone': normalized, 'text': message},
    );
    try {
      if (await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
        return WhatsAppLaunchResult.opened;
      }
    } catch (_) {}

    final webUri = buildWebUri(phone: normalized, message: message)!;
    try {
      if (await launchUrl(webUri, mode: LaunchMode.externalApplication)) {
        return WhatsAppLaunchResult.opened;
      }
    } catch (_) {}
    return WhatsAppLaunchResult.unavailable;
  }
}
