import 'dart:convert';

/// Converts SQLite representations to the REST contract without altering the
/// encrypted local snapshot or the operation's idempotency key.
Map<String, dynamic> decodeSyncPayload(String encoded) {
  final payload = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
  for (final key in const ['treatmentPlan', 'photos']) {
    if (payload[key] is String) {
      payload[key] = jsonDecode(payload[key] as String);
    }
  }
  for (final key in const ['reminderSent', 'notificationSent']) {
    if (payload.containsKey(key)) {
      payload[key] = payload[key] == true || payload[key] == 1;
    }
  }
  return payload;
}
