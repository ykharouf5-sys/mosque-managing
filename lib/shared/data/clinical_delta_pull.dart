/// Transport-independent clinical pagination. Database and authenticated
/// context checks are supplied by the existing SyncService, not duplicated.
class ClinicalDeltaPull {
  static Future<bool> run({
    required int scopeVersion,
    required void Function() ensureCurrent,
    required Future<Map<String, dynamic>> Function(String? cursor) requestPage,
    required Future<void> Function(Map<String, dynamic> row) applyPatient,
    required Future<void> Function(Map<String, dynamic> row) applyAppointment,
    required Future<void> Function(String serverTime) commitCheckpoint,
    required Future<void> Function() scopeChanged,
  }) async {
    String? cursor;
    String? watermark;
    var changed = false;
    final seen = <String>{};
    do {
      ensureCurrent();
      final data = await requestPage(cursor);
      ensureCurrent();
      final returnedScope = data['scope_version'];
      if (returnedScope is! num ||
          returnedScope < 1 ||
          returnedScope != returnedScope.toInt() ||
          data['patients'] is! List ||
          data['appointments'] is! List ||
          data['server_time'] is! String ||
          DateTime.tryParse(data['server_time'] as String) == null ||
          !data.containsKey('next_cursor') ||
          data['reset_required'] is! bool ||
          (data['next_cursor'] != null && data['next_cursor'] is! String) ||
          (watermark != null && watermark != data['server_time'])) {
        throw StateError('Invalid clinical delta page or changed watermark.');
      }
      if (data['reset_required'] == true || returnedScope != scopeVersion) {
        ensureCurrent();
        await scopeChanged();
        throw StateError('Clinical scope changed; restart initial sync.');
      }
      final patients = data['patients'] as List;
      final appointments = data['appointments'] as List;
      for (final row in [...patients, ...appointments]) {
        if (row is! Map ||
            row['id'] is! String ||
            (row['id'] as String).isEmpty ||
            row['version'] is! num ||
            (row['version'] as num) < 1 ||
            row['version'] != (row['version'] as num).toInt() ||
            row['updated_at'] is! String ||
            DateTime.tryParse(row['updated_at'] as String) == null ||
            !row.containsKey('deleted_at') ||
            (row['deleted_at'] != null &&
                (row['deleted_at'] is! String ||
                    DateTime.tryParse(row['deleted_at'] as String) == null))) {
          throw StateError('Invalid clinical delta record.');
        }
      }
      final next = data['next_cursor'] as String?;
      if (next != null && (next.isEmpty || !seen.add(next))) {
        throw StateError('Clinical cursor did not advance.');
      }
      for (final row in patients) {
        ensureCurrent();
        await applyPatient(Map<String, dynamic>.from(row as Map));
        ensureCurrent();
        changed = true;
      }
      for (final row in appointments) {
        ensureCurrent();
        await applyAppointment(Map<String, dynamic>.from(row as Map));
        ensureCurrent();
        changed = true;
      }
      cursor = next;
      watermark = data['server_time'] as String;
    } while (cursor != null);
    ensureCurrent();
    await commitCheckpoint(watermark);
    ensureCurrent();
    return changed;
  }
}
