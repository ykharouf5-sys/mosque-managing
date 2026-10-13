import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studentry/shared/cache/cache_manager.dart';
import 'package:studentry/store/presentation/providers/store_providers.dart';
import 'package:studentry/store/presentation/catalog_page_controls.dart';
import 'package:studentry/store/data/store_api_service.dart';
import 'package:studentry/store/data/store_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('category count comes from server, not the current product page', () {
    final category = ProductCategory.fromJson(
      StoreApiService.rowToCategoryMap({
        'id': 'category-1',
        'name': 'Dental',
        'icon_url': '',
        'products_count': 42,
      }),
    );
    expect(category.productCount, 42);
    expect(ProductCategory.fromJson(category.toJson()).productCount, 42);
  });
  test('empty server snapshot replaces old catalog on re-entry', () async {
    SharedPreferences.setMockInitialValues({});
    await CacheManager.instance.init();
    await CacheManager.instance.invalidateAll();
    await CacheManager.instance.set(CatalogNotifier.summaryCacheKey, {
      'categories': [
        {'id': 'c1', 'label': 'Old', 'iconUrl': ''},
      ],
      'banners': [],
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(catalogProvider.notifier);
    expect(notifier.restoreSnapshot(), true);
    expect(container.read(catalogProvider).categories, hasLength(1));
    await CacheManager.instance.set(CatalogNotifier.summaryCacheKey, {
      'categories': [],
      'banners': [],
    });
    expect(notifier.restoreSnapshot(), true);
    expect(container.read(catalogProvider).categories, isEmpty);
    expect(
      CatalogNotifier.pageCacheKey(1),
      isNot(CatalogNotifier.pageCacheKey(2)),
    );
    expect(
      CatalogNotifier.pageCacheKey(1, academicYear: 'الأولى'),
      isNot(CatalogNotifier.pageCacheKey(1, academicYear: 'الثانية')),
    );
  });

  test(
    'cached catalog retains server pagination while refresh is deferred',
    () async {
      SharedPreferences.setMockInitialValues({});
      await CacheManager.instance.init();
      await CacheManager.instance.invalidateAll();
      await CacheManager.instance.set(CatalogNotifier.summaryCacheKey, {
        'categories': [],
        'banners': [],
        'version': 'v1',
      });
      await CacheManager.instance.set(
        CatalogNotifier.pageCacheKey(1),
        <dynamic>[],
      );
      await CacheManager.instance.set(CatalogNotifier.pageMetadataCacheKey(1), {
        'lastPage': 7,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(catalogProvider.notifier);
      expect(notifier.restoreSnapshot(), true);
      expect(notifier.hasCachedProductPage, true);
      expect(notifier.hasCachedPagination, true);
      expect(container.read(catalogProvider).lastProductPage, 7);
      expect(container.read(catalogProvider).hasMoreProducts, true);
    },
  );

  testWidgets(
    'RTL pagination disables bounds and requests only selected page',
    (tester) async {
      int? requested;
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SizedBox(
                width: 280,
                child: CatalogPageControls(
                  page: 1,
                  lastPage: 3,
                  loading: false,
                  onPage: (page) => requested = page,
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'السابق'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('التالي'));
      expect(requested, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
