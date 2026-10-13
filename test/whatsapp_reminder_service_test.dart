import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/patients/data/whatsapp_reminder_service.dart';

void main() {
  group('WhatsAppReminderService.normalizePhone', () {
    test('normalizes Syrian local mobile numbers', () {
      expect(
        WhatsAppReminderService.normalizePhone('0944 123 456'),
        '963944123456',
      );
    });

    test('keeps international numbers and removes formatting', () {
      expect(
        WhatsAppReminderService.normalizePhone('+963 944-123-456'),
        '963944123456',
      );
      expect(
        WhatsAppReminderService.normalizePhone('00963 944 123 456'),
        '963944123456',
      );
    });

    test('rejects empty and implausible numbers', () {
      expect(WhatsAppReminderService.normalizePhone(''), isNull);
      expect(WhatsAppReminderService.normalizePhone('123'), isNull);
    });
  });

  test('buildWebUri targets wa.me without a plus sign', () {
    final uri = WhatsAppReminderService.buildWebUri(
      phone: '0944 123 456',
      message: 'تذكير بالموعد',
    );

    expect(uri, isNotNull);
    expect(uri!.host, 'wa.me');
    expect(uri.path, '/963944123456');
    expect(uri.queryParameters['text'], 'تذكير بالموعد');
  });
}
