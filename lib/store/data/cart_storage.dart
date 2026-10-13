import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'store_models.dart';

/// Account-scoped cart snapshots; catalog cache eviction never removes a cart.
class CartStorage {
  static Future<void> _writes = Future.value();

  static String key(String baseUrl, String userId) =>
      'store:cart:v1:$baseUrl:$userId';

  static Future<List<CartItem>> load(String key) async {
    await _writes;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map(
            (row) => CartItem.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .where((item) => item.quantity > 0)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(String key, List<CartItem> items) {
    // Serialize an immutable snapshot now; subsequent quantity mutations must
    // not change an earlier queued write.
    final encoded = jsonEncode(items.map((item) => item.toJson()).toList());
    final pending = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, encoded)) {
        throw StateError('Cart persistence failed');
      }
    });
    _writes = pending.catchError((Object _) {});
    return pending;
  }
}
