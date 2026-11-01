import 'dart:convert';
import 'package:studentry/shared/data/api_config.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/shared/data/encryption_service.dart';
import 'cache_manager.dart';

/// Re-downloadable private snapshots. Pending writes remain in encrypted SQLite.
class AccountSnapshotCache {
  static const ttl = Duration(days: 7);
  static String? key(String resource) {
    final user = AuthService().currentUser;
    if (user == null) return null;
    return 'private:v1:${ApiConfig.baseUrl}:${user.id}:${user.clinicId}:${user.clinicalScopeVersion}:${user.role}:$resource';
  }

  static Future<Map<String, dynamic>?> load(String? key) async {
    if (key == null) return null;
    try {
      final cipher = CacheManager.instance.get<String>(key);
      if (cipher == null) return null;
      return Map<String, dynamic>.from(
        jsonDecode(await EncryptionService.decrypt(cipher)) as Map,
      );
    } catch (_) {
      CacheManager.instance.remove(key);
      return null;
    }
  }

  static Future<void> save(
    String? key,
    Map<String, dynamic> value, {
    required int generation,
  }) async {
    if (key == null || generation != AuthService().sessionGeneration) return;
    final raw = jsonEncode(value);
    if (utf8.encode(raw).length > 1024 * 1024) return;
    final cipher = await EncryptionService.encrypt(raw);
    if (generation != AuthService().sessionGeneration) return;
    await CacheManager.instance.set(
      key,
      cipher,
      ttl: ttl,
      tags: [CacheTags.orders, 'notifications'],
    );
  }
}
