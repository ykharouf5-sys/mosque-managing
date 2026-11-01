import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studentry/shared/cache/account_snapshot_cache.dart';
import 'package:studentry/shared/cache/cache_manager.dart';
import 'package:studentry/shared/data/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await CacheManager.instance.init();
    await CacheManager.instance.invalidateAll();
  });
  test(
    'private snapshots are encrypted, paginated and expire after seven days',
    () async {
      const key = 'private:test:account-a:orders';
      await AccountSnapshotCache.save(key, {
        'orders': ['private address'],
      }, generation: AuthService().sessionGeneration);
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString('cache:$key')!;
      expect(encoded.contains('private address'), isFalse);
      final expires = DateTime.parse(jsonDecode(encoded)['e'] as String);
      expect(
        expires.difference(DateTime.now()).inHours,
        inInclusiveRange(167, 168),
      );
      expect((await AccountSnapshotCache.load(key))!['orders'], [
        'private address',
      ]);
      expect(
        await AccountSnapshotCache.load('private:test:account-b:orders'),
        isNull,
      );
      await CacheManager.instance.set(
        key,
        'expired',
        ttl: const Duration(seconds: -1),
      );
      expect(await AccountSnapshotCache.load(key), isNull);
    },
  );
  test('late writes from a previous session are ignored', () async {
    const key = 'private:test:old:orders';
    await AccountSnapshotCache.save(key, {
      'orders': [],
    }, generation: AuthService().sessionGeneration - 1);
    expect(await AccountSnapshotCache.load(key), isNull);
  });
}
