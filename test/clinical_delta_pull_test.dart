import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/shared/data/clinical_delta_pull.dart';

void main() {
  Map<String, dynamic> row(String id) => {
    'id': id,
    'version': 1,
    'updated_at': '2026-10-08T12:00:00Z',
    'deleted_at': null,
  };
  Map<String, dynamic> page({
    String? next,
    List<dynamic>? patients,
    int scope = 1,
    String time = '2026-10-08T12:00:00Z',
  }) => {
    'scope_version': scope,
    'patients': patients ?? [],
    'appointments': [],
    'next_cursor': next,
    'server_time': time,
    'reset_required': false,
  };
  late List<String> applied;
  late List<String> checkpoints;
  late bool current;
  setUp(() {
    applied = [];
    checkpoints = [];
    current = true;
  });
  Future<bool> pull(
    Future<Map<String, dynamic>> Function(String?) request, {
    Future<void> Function(Map<String, dynamic>)? apply,
    Future<void> Function()? scopeChanged,
  }) => ClinicalDeltaPull.run(
    scopeVersion: 1,
    ensureCurrent: () {
      if (!current) throw StateError('stale account');
    },
    requestPage: request,
    applyPatient:
        apply ??
        (row) async {
          applied.add(row['id'] as String);
        },
    applyAppointment: (_) async {},
    commitCheckpoint: (time) async {
      checkpoints.add(time);
    },
    scopeChanged: scopeChanged ?? () async {},
  );

  test('initial sync commits once only after every page and row', () async {
    var calls = 0;
    await pull((cursor) async {
      calls++;
      if (cursor == null) return page(next: 'page2', patients: [row('p1')]);
      expect(cursor, 'page2');
      expect(checkpoints, isEmpty);
      expect(applied, ['p1']);
      return page(patients: [row('p2')]);
    });
    expect(calls, 2);
    expect(applied, ['p1', 'p2']);
    expect(checkpoints, ['2026-10-08T12:00:00Z']);
  });

  test(
    'failed second page leaves checkpoint unchanged for safe replay',
    () async {
      await expectLater(
        pull((cursor) async {
          if (cursor == null) return page(next: 'page2', patients: [row('p1')]);
          throw StateError('offline');
        }),
        throwsStateError,
      );
      expect(applied, ['p1']);
      expect(checkpoints, isEmpty);
      applied.clear();
      await pull((_) async => page(patients: [row('p1'), row('p2')]));
      expect(checkpoints, hasLength(1));
    },
  );

  test(
    'late HTTP response after account switch cannot apply or checkpoint',
    () async {
      final response = Completer<Map<String, dynamic>>();
      final flight = pull((_) => response.future);
      final assertion = expectLater(flight, throwsStateError);
      current = false;
      response.complete(page(patients: [row('A-private')]));
      await assertion;
      expect(applied, isEmpty);
      expect(checkpoints, isEmpty);
    },
  );

  test(
    'account switch during local apply prevents later rows and checkpoint',
    () async {
      await expectLater(
        pull(
          (_) async => page(patients: [row('p1'), row('p2')]),
          apply: (row) async {
            applied.add(row['id']);
            current = false;
          },
        ),
        throwsStateError,
      );
      expect(applied, ['p1']);
      expect(checkpoints, isEmpty);
    },
  );

  test(
    'malformed rows are rejected before any row from that page is written',
    () async {
      await expectLater(
        pull(
          (_) async => page(
            patients: [
              row('p1'),
              {'id': 'bad'},
            ],
          ),
        ),
        throwsStateError,
      );
      expect(applied, isEmpty);
      expect(checkpoints, isEmpty);
    },
  );

  test(
    'scope mismatch cannot activate or populate an unrelated account',
    () async {
      var refreshes = 0;
      await expectLater(
        pull(
          (_) async => page(scope: 2, patients: [row('revoked')]),
          scopeChanged: () async {
            refreshes++;
          },
        ),
        throwsStateError,
      );
      expect(refreshes, 1);
      expect(applied, isEmpty);
      expect(checkpoints, isEmpty);
    },
  );

  test(
    'repeated cursor or changed snapshot cannot advance checkpoint',
    () async {
      await expectLater(
        pull((_) async => page(next: 'same')),
        throwsStateError,
      );
      expect(checkpoints, isEmpty);
      await expectLater(
        pull(
          (cursor) async => cursor == null
              ? page(next: 'second')
              : page(time: '2026-10-08T12:01:00Z'),
        ),
        throwsStateError,
      );
      expect(checkpoints, isEmpty);
    },
  );

  test('failed local transaction prevents successful checkpoint', () async {
    await expectLater(
      pull(
        (_) async => page(patients: [row('p1')]),
        apply: (_) async => throw StateError('SQL commit failed'),
      ),
      throwsStateError,
    );
    expect(checkpoints, isEmpty);
  });

  test(
    'missing pagination metadata cannot masquerade as a complete initial sync',
    () async {
      final incomplete = page(patients: [row('p1')])..remove('next_cursor');
      await expectLater(pull((_) async => incomplete), throwsStateError);
      expect(applied, isEmpty);
      expect(checkpoints, isEmpty);
    },
  );
}
