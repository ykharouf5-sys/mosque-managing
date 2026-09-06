import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/shared/data/sync_payload.dart';

void main() {
  test('SQLite patient JSON columns are restored before REST upload', () {
    final payload = decodeSyncPayload(r'''
      {"name":"Ahmad","treatmentPlan":"[{\"procedureName\":\"Filling\"}]","photos":"[\"local.jpg\"]"}
    ''');

    expect(payload['treatmentPlan'], isA<List<dynamic>>());
    expect(payload['treatmentPlan'][0]['procedureName'], 'Filling');
    expect(payload['photos'], ['local.jpg']);
  });

  test('SQLite appointment flags are restored as REST booleans', () {
    final payload = decodeSyncPayload(
      '{"reminderSent":1,"notificationSent":0}',
    );

    expect(payload['reminderSent'], isTrue);
    expect(payload['notificationSent'], isFalse);
  });
}
