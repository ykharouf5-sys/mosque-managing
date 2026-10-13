import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/shared/data/clinical_sync_policy.dart';

void main() {
  late DateTime clock;
  late ClinicalSyncPolicy policy;
  setUp(() {
    clock = DateTime.utc(2026, 10, 8);
    policy = ClinicalSyncPolicy(now: () => clock);
  });

  test('initial pull bypasses cooldown; only success starts 20 seconds', () {
    expect(policy.allowPull('A:clinic1:session1:g1:clinical'), isTrue);
    // A failed attempt is not a successful pull.
    expect(policy.allowPull('A:clinic1:session1:g1:clinical'), isTrue);
    policy.succeeded('A:clinic1:session1:g1:clinical');
    clock = clock.add(const Duration(seconds: 19));
    expect(policy.allowPull('A:clinic1:session1:g1:clinical'), isFalse);
    clock = clock.add(const Duration(seconds: 1));
    expect(policy.allowPull('A:clinic1:session1:g1:clinical'), isTrue);
  });

  test('manual refresh has its own three-second guard', () {
    policy.allowPull('A');
    policy.succeeded('A');
    expect(policy.allowPull('A'), isFalse);
    expect(policy.allowPull('A', manual: true), isTrue);
    clock = clock.add(const Duration(milliseconds: 2999));
    expect(policy.allowPull('A', manual: true), isFalse);
    clock = clock.add(const Duration(milliseconds: 1));
    expect(policy.allowPull('A', manual: true), isTrue);
  });

  test('Retry-After blocks automatic, manual and forced pulls', () {
    policy.allowPull('A');
    policy.defer('A', clock.add(const Duration(seconds: 60)));
    clock = clock.add(const Duration(seconds: 20));
    expect(policy.allowPull('A'), isFalse);
    expect(policy.allowPull('A', manual: true), isFalse);
    expect(policy.allowPull('A', force: true), isFalse);
    clock = clock.add(const Duration(seconds: 40));
    expect(policy.allowPull('A', manual: true), isTrue);
  });

  test(
    'each account, clinic, scope, session and database generation is isolated',
    () {
      for (final context in [
        'A:c1:v1:s1:g1',
        'B:c1:v1:s2:g2',
        'B:c2:v1:s2:g3',
        'B:c2:v2:s3:g4',
        'B:c2:v2:s4:g4',
      ]) {
        expect(policy.allowPull(context), isTrue);
        policy.succeeded(context);
        expect(policy.allowPull(context), isFalse);
      }
    },
  );

  test('late success or failure from A cannot suppress account B', () {
    policy.allowPull('A');
    policy.allowPull('B');
    policy.succeeded('A');
    policy.defer('A', clock.add(const Duration(hours: 1)));
    expect(policy.allowPull('B'), isTrue);
  });

  test('a shorter retry cannot remove a longer server backoff', () {
    policy.allowPull('A');
    policy.defer('A', clock.add(const Duration(minutes: 2)));
    policy.defer('A', clock.add(const Duration(seconds: 10)));
    clock = clock.add(const Duration(minutes: 1));
    expect(policy.allowPull('A', manual: true), isFalse);
  });

  test(
    'rapid tab events share clinical cooldown; staying idle emits nothing',
    () {
      var requests = 0;
      for (var second = 0; second < 61; second++) {
        if (policy.allowPull('clinical-shared')) {
          requests++;
          policy.succeeded('clinical-shared');
        }
        clock = clock.add(const Duration(seconds: 1));
      }
      expect(requests, 4);
      clock = clock.add(const Duration(minutes: 30));
      expect(requests, 4); // Advancing time does not issue a network request.
    },
  );
}
