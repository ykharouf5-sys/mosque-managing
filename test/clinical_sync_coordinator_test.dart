import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/shared/data/clinical_sync_coordinator.dart';
import 'package:studentry/shared/data/clinical_sync_policy.dart';

void main() {
  late ClinicalSyncCoordinator<ClinicalSyncFlight> flights;
  late DateTime clock;
  setUp(() {
    clock = DateTime.utc(2026, 10, 8);
    flights = ClinicalSyncCoordinator(ClinicalSyncPolicy(now: () => clock));
  });
  Future<bool> start(
    String key,
    Future<bool> Function(ClinicalSyncFlight) execute, {
    bool manual = false,
    bool pull = true,
  }) => flights.request(
    key: key,
    manual: manual,
    pullChanges: pull,
    create: (pull) => ClinicalSyncFlight(key: key, pullRequested: pull),
    execute: execute,
    onFinished: (_) async {},
  );

  test(
    'automatic and manual duplicate requests share the same future',
    () async {
      final gate = Completer<bool>();
      var runs = 0;
      final first = start('A:c1:s1:g1', (_) {
        runs++;
        return gate.future;
      });
      final second = start('A:c1:s1:g1', (_) async => false, manual: true);
      expect(identical(first, second), isTrue);
      expect(runs, 1);
      gate.complete(true);
      expect(await second, isTrue);
    },
  );

  test('a pull can join a push flight without starting another job', () async {
    final gate = Completer<bool>();
    final first = start('A', (_) => gate.future, pull: false);
    expect(flights.active!.pullRequested, isFalse);
    final second = start('A', (_) async => false);
    expect(flights.active!.pullRequested, isTrue);
    expect(identical(first, second), isTrue);
    gate.complete(true);
    await first;
  });

  test('late A completion cannot release B flight or share B result', () async {
    final a = Completer<bool>();
    final b = Completer<bool>();
    final old = start('A:s1:g1', (_) => a.future);
    final next = start('B:s2:g2', (_) => b.future);
    expect(identical(old, next), isFalse);
    a.complete(false);
    await old;
    expect(flights.active!.key, 'B:s2:g2');
    b.complete(true);
    await next;
    expect(flights.active, isNull);
  });

  test(
    'cooldown and Retry-After suppress pulls but never suppress pushes',
    () async {
      await start('A', (flight) async {
        expect(flight.pullRequested, isTrue);
        flights.policy.succeeded('A');
        return true;
      });
      var pushes = 0;
      await start('A', (flight) async {
        pushes++;
        expect(flight.pullRequested, isFalse);
        return true;
      });
      flights.policy.defer('A', clock.add(const Duration(minutes: 1)));
      await start('A', (flight) async {
        pushes++;
        expect(flight.pullRequested, isFalse);
        return true;
      }, manual: true);
      expect(pushes, 2);
    },
  );

  test('errors release ownership and allow a future retry', () async {
    await expectLater(
      start('A', (_) async => throw StateError('failed')),
      throwsStateError,
    );
    expect(flights.active, isNull);
    expect(await start('A', (_) async => true), isTrue);
  });

  test(
    'cleanup error completes the request with an error rather than hanging',
    () async {
      final result = flights.request(
        key: 'A',
        create: (pull) => ClinicalSyncFlight(key: 'A', pullRequested: pull),
        execute: (_) async => true,
        onFinished: (_) async => throw StateError('cleanup failed'),
      );
      await expectLater(result, throwsStateError);
      expect(flights.active, isNull);
    },
  );
}
