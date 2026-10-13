import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'encryption_service.dart';

/// Called under the same transaction as the visible clinical write.
class ClinicalOutbox {
  static Future<void> enqueue(
    DatabaseExecutor txn,
    Map<String, Object?> incoming,
  ) async {
    final table = incoming['table_name'];
    if (table != 'patients' && table != 'appointments') {
      await txn.insert('sync_queue', incoming);
      return;
    }
    final previous = await txn.query(
      'sync_queue',
      where: 'table_name = ? AND record_id = ?',
      whereArgs: [table, incoming['record_id']],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (previous.isEmpty || !_untouched(previous.single)) {
      await txn.insert('sync_queue', incoming);
      return;
    }
    final head = previous.single;
    final oldOperation = head['operation'];
    final newOperation = incoming['operation'];
    if ((oldOperation != 'insert' && oldOperation != 'update') ||
        (newOperation != 'update' && newOperation != 'delete')) {
      await txn.insert('sync_queue', incoming);
      return;
    }
    final intervening = await txn.query(
      'sync_queue',
      where: 'id > ?',
      whereArgs: [head['id']],
      orderBy: 'id',
    );
    for (final row in intervening) {
      // Do not move a change across a payment, dependent appointment, or
      // another booking whose time-conflict outcome could depend on ordering.
      if (row['table_name'] == 'patients') continue;
      if (table == 'appointments' ||
          (row['table_name'] != 'appointments' &&
              row['table_name'] != 'patient_payments')) {
        await txn.insert('sync_queue', incoming);
        return;
      }
      final body = await _decode(row['payload'] as String);
      if (body['patientId'] == incoming['record_id']) {
        await txn.insert('sync_queue', incoming);
        return;
      }
    }
    final oldBody = await _decode(head['payload'] as String);
    final newBody = await _decode(incoming['payload'] as String);
    if (oldOperation == 'insert' && newOperation == 'delete') {
      if (!await _canCancelCreate(txn, head, oldBody)) {
        await txn.insert('sync_queue', incoming);
        return;
      }
      await txn.delete('sync_queue', where: 'id = ?', whereArgs: [head['id']]);
      // Retain the local tombstone; no server operation is needed for it.
      await txn.update(
        table as String,
        {'is_synced': 1},
        where: 'id = ? AND deleted_at IS NOT NULL',
        whereArgs: [incoming['record_id']],
      );
      return;
    }
    final merged = newOperation == 'delete'
        ? <String, dynamic>{...newBody}
        : <String, dynamic>{...oldBody, ...newBody};
    // All coalesced edits are based on the original server version.
    if (oldBody.containsKey('version')) merged['version'] = oldBody['version'];
    await txn.update(
      'sync_queue',
      {
        'operation': newOperation == 'delete' ? 'delete' : oldOperation,
        'payload': await EncryptionService.encrypt(jsonEncode(merged)),
      },
      where: 'id = ?',
      whereArgs: [head['id']],
    );
  }

  static bool _untouched(Map<String, Object?> row) =>
      row['attempted'] == 0 &&
      row['status'] == 'pending' &&
      row['retry_count'] == 0;

  static Future<Map<String, dynamic>> _decode(String payload) async =>
      Map<String, dynamic>.from(
        jsonDecode(await EncryptionService.decrypt(payload)) as Map,
      );

  static Future<bool> _canCancelCreate(
    DatabaseExecutor txn,
    Map<String, Object?> head,
    Map<String, dynamic> body,
  ) async {
    final earlier = await txn.query(
      'sync_queue',
      columns: ['id'],
      where: 'table_name = ? AND record_id = ? AND id < ?',
      whereArgs: [head['table_name'], head['record_id'], head['id']],
      limit: 1,
    );
    if (earlier.isNotEmpty) return false;
    if (head['table_name'] != 'patients') return true;
    // Financial events and children are retained even if locally deleted.
    final children = await txn.query(
      'appointments',
      columns: ['id'],
      where: 'patientId = ?',
      whereArgs: [head['record_id']],
      limit: 1,
    );
    if (children.isNotEmpty ||
        (body['photoUrl']?.toString().isNotEmpty ?? false) ||
        (body['photos'] != null && body['photos'].toString() != '[]')) {
      return false;
    }
    final related = await txn.query(
      'sync_queue',
      where: 'table_name IN (?, ?)',
      whereArgs: ['appointments', 'patient_payments'],
    );
    for (final row in related) {
      if ((await _decode(row['payload'] as String))['patientId'] ==
          head['record_id']) {
        return false;
      }
    }
    return true;
  }
}
