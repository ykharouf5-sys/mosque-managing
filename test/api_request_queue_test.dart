import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/shared/data/api_request_queue.dart';

void main() {
  test('API exception parses Retry-After case-insensitively', () {
    const error = ApiException(429, 'busy', null, {'Retry-After': '30'});

    expect(error.retryAfter, const Duration(seconds: 30));
  });

  test('API exception ignores invalid Retry-After values', () {
    const error = ApiException(429, 'busy', null, {'retry-after': 'later'});

    expect(error.retryAfter, isNull);
  });

  test(
    'retry queue retries transient server failures only up to the limit',
    () async {
      var attempts = 0;

      final value = await ApiRequestQueue.instance.add(() async {
        attempts++;
        if (attempts < 3) throw const ApiException(500, 'temporary');
        return 'ok';
      }, maxRetries: 2);

      expect(value, 'ok');
      expect(attempts, 3);
    },
  );

  test('retry queue does not retry validation failures', () async {
    var attempts = 0;

    await expectLater(
      ApiRequestQueue.instance.add(() async {
        attempts++;
        throw const ApiException(422, 'invalid');
      }, maxRetries: 3),
      throwsA(isA<ApiException>()),
    );

    expect(attempts, 1);
  });
}
