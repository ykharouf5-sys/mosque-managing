import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/store/data/order_retry_policy.dart';
import 'package:studentry/store/data/order_submission_result.dart';

void main() {
  test('retry backs off, remains bounded and honors server minimum delay', () {
    for (var attempt = 0; attempt < 8; attempt++) {
      final delay = OrderRetryPolicy.delay(attempt, random: Random(1));
      final base = OrderRetryPolicy.delays[attempt.clamp(0, 3)];
      expect(delay, greaterThanOrEqualTo(base));
      expect(delay, lessThan(base + const Duration(seconds: 1)));
    }
    expect(
      OrderRetryPolicy.delay(0, retryAfter: const Duration(hours: 1)),
      greaterThanOrEqualTo(const Duration(hours: 1)),
    );
    expect(
      const OrderSubmissionResult('payment_failed').isPermanentFailure,
      true,
    );
    expect(
      const OrderSubmissionResult('invalid_order').isPermanentFailure,
      true,
    );
    expect(const OrderSubmissionResult('error').isPermanentFailure, false);
  });
}
