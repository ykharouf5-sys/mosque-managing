class SyncBackoffPolicy {
  static const Duration _initialDelay = Duration(seconds: 5);
  static const Duration _maximumDelay = Duration(minutes: 15);
  static const Duration _maximumServerDelay = Duration(hours: 1);

  const SyncBackoffPolicy._();

  static Duration delayFor({
    required int retryCount,
    Duration? retryAfter,
    int jitterMilliseconds = 0,
  }) {
    final safeJitter = jitterMilliseconds.clamp(0, 3000);
    final Duration base;
    if (retryAfter != null) {
      final seconds = retryAfter.inSeconds.clamp(
        1,
        _maximumServerDelay.inSeconds,
      );
      base = Duration(seconds: seconds);
    } else {
      final exponent = retryCount.clamp(0, 8);
      final seconds = (_initialDelay.inSeconds * (1 << exponent)).clamp(
        _initialDelay.inSeconds,
        _maximumDelay.inSeconds,
      );
      base = Duration(seconds: seconds);
    }
    return base + Duration(milliseconds: safeJitter);
  }
}
