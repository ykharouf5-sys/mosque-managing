import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studentry/shared/cache/cache_manager.dart';
import 'package:studentry/shared/data/storage_usage.dart';
import 'package:studentry/management/presentation/storage_usage_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'cleanup removes expired snapshots, preserves favorites and user settings',
    () async {
      SharedPreferences.setMockInitialValues({'setting:language': 'ar'});
      final cache = CacheManager.instance;
      await cache.init();
      await cache.invalidateAll();
      await cache.set('catalog:test', 'snapshot', ttl: const Duration(days: 1));
      await cache.set('favorites:user', ['p1'], ttl: const Duration(days: 180));
      await cache.set('expired', 'gone', ttl: const Duration(seconds: -1));
      await cache.prune(maxBytes: 1);
      expect(cache.get<String>('catalog:test'), isNull);
      expect(cache.get<String>('expired'), isNull);
      expect(cache.get<List<String>>('favorites:user'), ['p1']);
      expect(
        (await SharedPreferences.getInstance()).getString('setting:language'),
        'ar',
      );
      await cache.set(
        'clinical:memory',
        'value',
        tags: [CacheTags.patients],
        persist: false,
      );
      await cache.prune();
      cache.invalidate(CacheTags.patients);
      expect(cache.get<String>('clinical:memory'), isNull);
      await cache.invalidateAll();
    },
  );

  testWidgets('storage breakdown fits a narrow RTL screen with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: Scaffold(
              body: StorageUsagePanel(
                usage: StorageUsage(databases: 30 * 1024 * 1024),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('30.0'), findsWidgets);
    await tester.scrollUntilVisible(find.text('تنظيف الملفات المؤقتة'), 200);
    expect(tester.takeException(), isNull);
  });
}
