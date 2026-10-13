import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:studentry/shared/data/api_config.dart';
import 'catalog_refresh_policy.dart';

class CatalogRefreshSchedule {
  CatalogRefreshSchedule({DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  SharedPreferences? _prefs;
  String? _key;
  String? _account;
  String _identity = '';
  DateTime? _next;
  int _failures = 0;

  DateTime? get nextRefreshAt => _next;
  Duration get delay {
    final remaining = _next?.difference(_now()) ?? CatalogRefreshPolicy.cycle;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> prepare(String? accountId) async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    const installationKey = 'catalog_refresh_installation_v1';
    var installation = prefs.getString(installationKey);
    if (installation == null) {
      installation = const Uuid().v4();
      await prefs.setString(installationKey, installation);
    }
    final account = accountId ?? 'guest';
    if (_account != account) {
      _account = account;
      _failures = 0;
      _identity = '$account:$installation';
      _key = 'catalog_refresh_next_v1:${ApiConfig.baseUrl}:$account';
      final stored = prefs.getInt(_key!);
      _next = stored == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(stored, isUtc: true);
    }
    final now = _now();
    if (_next == null ||
        _next!.difference(now) >
            CatalogRefreshPolicy.cycle + const Duration(minutes: 6)) {
      _next = CatalogRefreshPolicy.nextSlot(now, _identity);
    } else if (!_next!.isAfter(now)) {
      _next = now.add(CatalogRefreshPolicy.catchUpDelay(_identity));
    }
    await _persist();
  }

  Future<void> completed({required bool success}) async {
    if (_key == null) return;
    if (success) {
      _failures = 0;
      _next = CatalogRefreshPolicy.nextSlot(_now(), _identity);
    } else {
      _failures++;
      _next = _now().add(CatalogRefreshPolicy.retryDelay(_identity, _failures));
    }
    await _persist();
  }

  Future<void> _persist() async {
    if (_prefs != null && _key != null && _next != null) {
      await _prefs!.setInt(_key!, _next!.millisecondsSinceEpoch);
    }
  }
}
