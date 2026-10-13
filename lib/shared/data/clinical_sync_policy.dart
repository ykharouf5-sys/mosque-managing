/// Clinical pulls share a gate only within the same account, clinic, session,
/// database generation and appointment window. Pushes never use this gate.
class ClinicalSyncPolicy {
  ClinicalSyncPolicy({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const automaticCooldown = Duration(seconds: 20);
  static const manualGuard = Duration(seconds: 3);
  final DateTime Function() _now;
  String? _context;
  DateTime? _lastSuccessfulPull;
  DateTime? _lastManualRequest;
  DateTime? _blockedUntil;
  DateTime? get blockedUntil => _blockedUntil;

  void bind(String context) {
    if (_context == context) return;
    _context = context;
    _lastSuccessfulPull = null;
    _lastManualRequest = null;
    _blockedUntil = null;
  }

  bool allowPull(String context, {bool manual = false, bool force = false}) {
    bind(context);
    final now = _now();
    if (_blockedUntil != null && now.isBefore(_blockedUntil!)) return false;
    if (manual) {
      if (_lastManualRequest != null &&
          now.difference(_lastManualRequest!) < manualGuard) {
        return false;
      }
      _lastManualRequest = now;
      return true;
    }
    return force ||
        _lastSuccessfulPull == null ||
        now.difference(_lastSuccessfulPull!) >= automaticCooldown;
  }

  void succeeded(String context) {
    if (_context != context) return;
    _lastSuccessfulPull = _now();
    _blockedUntil = null;
  }

  void defer(String context, DateTime until) {
    if (_context != context) return;
    if (_blockedUntil == null || until.isAfter(_blockedUntil!)) {
      _blockedUntil = until;
    }
  }

  void clear() {
    _context = null;
    _lastSuccessfulPull = null;
    _lastManualRequest = null;
    _blockedUntil = null;
  }
}
