import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studentry/utils/app_locale.dart';
import 'package:studentry/store/data/cart_storage.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/store/data/store_api_service.dart';
import 'package:studentry/management/presentation/widgets/catalog_translation_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studentry/store/presentation/providers/store_providers.dart';

void main() {
  test(
    'sync refreshes cart copy while preserving historical cart money and coupon state',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      final cart = container.read(cartProvider.notifier);
      Product item(String name, double price) => Product(
        id: 'p',
        name: 'عربي',
        description: '',
        imageUrl: '',
        categoryId: '',
        categoryName: '',
        price: price,
        createdAt: DateTime.utc(2026),
        translations: {
          'ar': {'name': 'عربي'},
          'en': {'name': name},
        },
      );
      cart.addToCart(item('Before sync', 10), quantity: 3);
      cart.refreshProductCopy([item('After sync', 999)]);
      await AppLocale.setLocale('en');
      final snapshot = container.read(cartProvider);
      expect(snapshot.items.single.product.name, 'After sync');
      expect(snapshot.items.single.product.price, 10);
      expect(snapshot.items.single.quantity, 3);
      expect(snapshot.total, 30);
      container.dispose();
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppLocale.localeNotifier.value = const Locale('ar');
  });
  tearDown(() {
    AppLocale.localeNotifier.value = const Locale('ar');
  });
  Product product() => Product.fromJson({
    'id': 'p1',
    'name': 'فرشاة',
    'description': 'عربي',
    'imageUrl': 'shared.png',
    'categoryId': 'c1',
    'categoryName': 'فراشي',
    'price': 42,
    'stock': 8,
    'createdAt': '2026-10-12T00:00:00Z',
    'translations': {
      'ar': {'name': 'فرشاة', 'description': 'عربي'},
      'en': {'name': 'Toothbrush', 'description': 'English description'},
    },
    'categoryTranslations': {
      'ar': {'name': 'فراشي'},
      'en': {'name': 'Toothbrushes'},
    },
  });
  test(
    'existing language preference persists and unsupported locales are rejected',
    () async {
      await AppLocale.setLocale('en');
      expect((await AppLocale.getSavedLocale()).languageCode, 'en');
      expect(() => AppLocale.setLocale('fr'), throwsArgumentError);
    },
  );
  test(
    'offline cart changes copy immediately without price, quantity, identity or account changes',
    () async {
      final original = product();
      final key = CartStorage.key('https://example.test', 'a');
      await CartStorage.save(key, [CartItem(product: original, quantity: 3)]);
      await AppLocale.setLocale('en');
      final cart = await CartStorage.load(key);
      expect(cart.single.product.name, 'Toothbrush');
      expect(cart.single.product.categoryName, 'Toothbrushes');
      expect(cart.single.product.price, 42);
      expect(cart.single.quantity, 3);
      expect(cart.single.product.id, 'p1');
      expect(cart.single.totalPrice, 126);
      expect(
        await CartStorage.load(CartStorage.key('https://example.test', 'b')),
        isEmpty,
      );
      await AppLocale.setLocale('ar');
      expect(cart.single.product.name, 'فرشاة');
    },
  );
  test(
    'full copy survives cache serialization and a refreshed translation replaces old copy',
    () async {
      final cached = Product.fromJson(
        jsonDecode(jsonEncode(product().toJson())),
      );
      await AppLocale.setLocale('en');
      expect(cached.name, 'Toothbrush');
      final refreshed = cached.toJson();
      refreshed['translations'] = {
        'ar': {'name': 'فرشاة'},
        'en': {'name': 'Updated toothbrush'},
      };
      expect(Product.fromJson(refreshed).name, 'Updated toothbrush');
    },
  );
  test(
    'legacy offline products and missing English fields fall back to Arabic',
    () async {
      final legacy = product().toJson()
        ..remove('translations')
        ..remove('categoryTranslations');
      await AppLocale.setLocale('en');
      expect(Product.fromJson(legacy).name, 'فرشاة');
      final incomplete = product().toJson();
      incomplete['translations'] = {
        'ar': {'name': 'فرشاة', 'description': 'وصف'},
        'en': {'name': 'Brush', 'description': ''},
      };
      expect(Product.fromJson(incomplete).description, 'وصف');
    },
  );
  test(
    'wire conversions keep Arabic baseline and full category/banner copy',
    () async {
      final wire = StoreApiService.rowToProductMap({
        'id': 'p1',
        'name': 'English',
        'price': '42.00',
        'translations': {
          'ar': {'name': 'عربي'},
          'en': {'name': 'English'},
        },
      });
      expect(wire['name'], 'عربي');
      await AppLocale.setLocale('en');
      expect(Product.fromJson(wire).name, 'English');
      final banner = PromoBanner.fromJson(
        StoreApiService.rowToBannerMap({
          'id': 'b',
          'title': 'عرض',
          'image_url': 'shared.png',
          'translations': {
            'ar': {'title': 'عرض'},
            'en': {'title': 'Offer', 'image_url': 'english.png'},
          },
        }),
      );
      expect(banner.title, 'Offer');
      expect(banner.imageUrl, 'english.png');
      expect(
        ProductCategory.fromJson(
          StoreApiService.rowToCategoryMap({
            'id': 'c',
            'name': 'فئة',
            'translations': {
              'en': {'name': 'Category'},
            },
          }),
        ).label,
        'Category',
      );
    },
  );
  testWidgets(
    'translation tabs preserve both drafts and saved English on repeated switching',
    (tester) async {
      final ar = {'name': TextEditingController(text: 'اسم')};
      final en = {'name': TextEditingController(text: 'Saved English')};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CatalogTranslationEditor(
              arabic: ar,
              english: en,
              labels: const {'name': ('الاسم', 'Name')},
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'عربي محدث');
      await tester.tap(find.text('English'));
      await tester.pump();
      expect(find.text('Saved English'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'New English');
      await tester.tap(find.text('العربية'));
      await tester.pump();
      expect(find.text('عربي محدث'), findsOneWidget);
      expect(editorTranslations(ar, en)['en'], {'name': 'New English'});
      await tester.pumpWidget(const SizedBox());
      for (final c in [...ar.values, ...en.values]) {
        c.dispose();
      }
    },
  );
}
