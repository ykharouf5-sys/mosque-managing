import 'dart:math';

class OrderRetryPolicy {
  static const delays = [
    Duration(seconds: 5),
    Duration(seconds: 30),
    Duration(minutes: 2),
    Duration(minutes: 10),
  ];

  static Duration delay(int attempt, {Duration? retryAfter, Random? random}) {
    final base = delays[attempt.clamp(0, delays.length - 1)];
    final floor = retryAfter != null && retryAfter > base ? retryAfter : base;
    return floor + Duration(milliseconds: (random ?? Random()).nextInt(1000));
  }

  static DateTime? due(Map<String, dynamic> order) =>
      DateTime.tryParse(order['_nextRetryAt']?.toString() ?? '');
}
