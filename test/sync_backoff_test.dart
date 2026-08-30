import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/shared/data/sync_backoff.dart';

void main() {
  test('exponential backoff grows and is capped', () {
    expect(
      SyncBackoffPolicy.delayFor(retryCount: 0),
      const Duration(seconds: 5),
    );
    expect(
      SyncBackoffPolicy.delayFor(retryCount: 1),
      const Duration(seconds: 10),
    );
    expect(
      SyncBackoffPolicy.delayFor(retryCount: 99),
      const Duration(minutes: 15),
    );
  });

  test('Retry-After wins and receives bounded jitter', () {
    expect(
      SyncBackoffPolicy.delayFor(
        retryCount: 7,
        retryAfter: const Duration(seconds: 30),
        jitterMilliseconds: 1250,
      ),
      const Duration(milliseconds: 31250),
    );
  });

  test('server Retry-After is capped to one hour', () {
    expect(
      SyncBackoffPolicy.delayFor(
        retryCount: 0,
        retryAfter: const Duration(days: 2),
      ),
      const Duration(hours: 1),
    );
  });
}
