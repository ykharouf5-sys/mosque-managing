import 'package:studentry/shared/data/api_config.dart';

/// Stable device/account cohorts. No timers, native APIs or network dependencies.
class CatalogRefreshPolicy {
  static const cycle = ApiConfig.catalogRefreshInterval;
  static const batchWidth = Duration(minutes: 1);
  static const batchCount = 120;

  static int _hash(String value) {
    var hash = 2166136261;
    for (final byte in value.codeUnits) {
      hash = _multiply32(hash ^ byte, 16777619);
    }
    // Avalanche the low bits before modulo; plain FNV has parity correlations
    // for related account/device strings and can leave half the cohorts unused.
    hash ^= hash >>> 16;
    hash = _multiply32(hash, 0x85ebca6b);
    hash ^= hash >>> 13;
    hash = _multiply32(hash, 0xc2b2ae35);
    hash ^= hash >>> 16;
    return hash;
  }

  // Split multiplication so the low 32 bits also match in the web preview,
  // where integers use a 53-bit mantissa instead of native integer arithmetic.
  static int _multiply32(int value, int factor) =>
      (((value & 0xffff) * factor) +
          ((((value >>> 16) * factor) & 0xffff) << 16)) &
      0xffffffff;

  static int batch(String identity) => _hash(identity) % batchCount;

  static DateTime nextSlot(DateTime now, String identity) {
    final cycleMs = cycle.inMilliseconds;
    final offset =
        batch(identity) * batchWidth.inMilliseconds +
        _hash('$identity:within-batch') % batchWidth.inMilliseconds;
    var slot = (now.millisecondsSinceEpoch ~/ cycleMs) * cycleMs + offset;
    if (slot <= now.millisecondsSinceEpoch) slot += cycleMs;
    return DateTime.fromMillisecondsSinceEpoch(slot, isUtc: true);
  }

  // A foreground/resume wave must not trigger all overdue devices immediately.
  static Duration catchUpDelay(String identity) =>
      Duration(milliseconds: 1000 + _hash('$identity:catch-up') % 300000);

  static Duration retryDelay(String identity, int failures) {
    final minutes = (5 * (1 << (failures - 1).clamp(0, 3))).clamp(5, 30);
    return Duration(
      milliseconds:
          Duration(minutes: minutes).inMilliseconds +
          _hash('$identity:retry-$failures') % 60000,
    );
  }
}
