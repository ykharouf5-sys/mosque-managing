import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/data/api_request_queue.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/data/request_diagnostics.dart';
import 'academic_api_service.dart';
import 'academic_local_store.dart';

class AcademicDeltaSync {
  static Future<void>? _running;
  static int? _generation;

  static Future<void> pull({ApiClient? client}) {
    final generation = AppDatabase.captureActiveDataGeneration();
    if (_running != null && _generation == generation) return _running!;
    _generation = generation;
    late final Future<void> run;
    run = _pull(client ?? ApiClient.instance, generation).whenComplete(() {
      if (identical(_running, run)) _running = null;
    });
    _running = run;
    return run;
  }

  static Future<void> _pull(ApiClient api, int generation) async {
    final checkpoint = await AcademicLocalStore.syncCheckpoint(generation);
    final changes = <String, List<Map<String, dynamic>>>{
      'subjects': [],
      'enrollments': [],
    };
    String? cursor;
    var reset = false;
    final seen = <String>{};
    for (var page = 0; page < 10000; page++) {
      AppDatabase.ensureDataGeneration(generation);
      ApiResult result;
      try {
        result = await api.get(
          '/academic/sync/pull',
          query: {
            'limit': '25',
            if (cursor != null) 'cursor': cursor else 'checkpoint': ?checkpoint,
          },
          force: true,
          maxRetries: 0,
          reason: RequestReason.sync,
        );
      } on ApiException catch (error) {
        // An installed old server keeps the existing full-list contract. Never
        // fall back on permissions, conflicts or a failed continuation page.
        if (page != 0 || ![404, 405].contains(error.statusCode)) rethrow;
        final legacy = AcademicApiService(client: api);
        final subjects = await legacy.subjects(force: true);
        final enrollments = await legacy.enrollments(force: true);
        AppDatabase.ensureDataGeneration(generation);
        await AcademicLocalStore.applySync(
          {
            'subjects': subjects
                .map(
                  (row) => {
                    'id': row.id,
                    'deleted': false,
                    'row': row.toJson(),
                  },
                )
                .toList(),
            'enrollments': enrollments
                .map(
                  (row) => {
                    'id': row.enrollmentId,
                    'deleted': false,
                    'row': row.toJson(),
                  },
                )
                .toList(),
          },
          reset: true,
          checkpoint: null,
          generation: generation,
        );
        return;
      }
      AppDatabase.ensureDataGeneration(generation);
      final data = result.data;
      if (data is! Map ||
          data['changes'] is! Map ||
          data['reset_required'] is! bool) {
        throw const FormatException('Invalid academic delta response');
      }
      if (data['reset_required'] == true) {
        reset = true;
        for (final rows in changes.values) {
          rows.clear();
        }
      }
      for (final collection in changes.keys) {
        final rows = data['changes'][collection];
        if (rows is! List || rows.length > 25) {
          throw const FormatException('Invalid academic delta page');
        }
        for (final raw in rows) {
          if (raw is! Map ||
              raw['id'] is! String ||
              (raw['id'] as String).isEmpty ||
              raw['deleted'] is! bool) {
            throw const FormatException('Invalid academic delta change');
          }
          final change = Map<String, dynamic>.from(raw);
          if (change['deleted'] == false) {
            final row = change['row'];
            if (row is! Map ||
                row[collection == 'subjects' ? 'id' : 'enrollmentId'] !=
                    change['id']) {
              throw const FormatException('Invalid academic delta row');
            }
          }
          changes[collection]!.add(change);
        }
      }
      final next = data['next_cursor'];
      if (next == null) {
        final completed = data['checkpoint'];
        if (completed is! String || completed.isEmpty) {
          throw const FormatException('Missing academic checkpoint');
        }
        await AcademicLocalStore.applySync(
          changes,
          reset: reset,
          checkpoint: completed,
          generation: generation,
        );
        return;
      }
      if (next is! String || next.isEmpty || !seen.add(next)) {
        throw const FormatException('Invalid academic delta cursor');
      }
      cursor = next;
    }
    throw const FormatException('Academic delta exceeded page limit');
  }
}
