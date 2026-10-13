import 'dart:convert';

/// Patient CRUD uses the resource REST endpoint and its returned version.
/// Keep dependent appointments/payments in outbox order on the same page.
bool canBatchClinicalOperations(
  Iterable<({String tableName, String operation})> operations,
) => !operations.any((item) => item.tableName == 'patients');

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

/// The deployed older sync endpoint has CAS and increments once per accepted
/// mutation, but its replay receipt has no version. Derive that exact version
/// from the immutable acknowledged operation, never from a later GET snapshot.
int clinicalAcknowledgedVersion({
  required String operation,
  required Map<String, dynamic> payload,
  required Map<String, dynamic> receipt,
}) {
  if (receipt['status'] != 'accepted') {
    throw StateError('Clinical operation was not acknowledged.');
  }
  final returned = receipt['version'];
  if (returned is num && returned >= 1 && returned == returned.toInt()) {
    return returned.toInt();
  }
  if (operation == 'insert') return 1;
  final base = payload['version'];
  if (base is num && base >= 1 && base == base.toInt()) return base.toInt() + 1;
  throw StateError('Acknowledgement has no safe record version.');
}
