import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/store/presentation/widgets/category_outline_icon.dart';
import 'package:studentry/store/presentation/widgets/store_promo_card.dart';

void main() {
  for (final width in [288.0, 380.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('Arabic banner fits $width px with text scale $scale', (
        tester,
      ) async {
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Center(
                  child: SizedBox(
                    width: width,
                    height: (width / 2).clamp(180.0, 230.0) + (18 * scale - 18),
                    child: StorePromoCard(
                      banner: const PromoBanner(
                        id: 'demo',
                        title: 'جهّز أدوات التدريب',
                        subtitle: 'أدوات فحص لطلاب طب الأسنان',
                        discountText: 'مستلزمات الدراسة',
                        imageUrl: '',
                        ctaText: 'استكشف المنتجات',
                        actionRoute: '/category-products',
                      ),
                      image: const ColoredBox(color: Color(0xFFB7E0E3)),
                      onTap: () => tapped = true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('استكشف المنتجات'));
        expect(tapped, isTrue);
      });
    }
  }

  testWidgets('category symbols render as small outlines', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            CategoryOutlineIcon(label: 'أدوات الفحص'),
            CategoryOutlineIcon(label: 'مواد الترميم'),
            CategoryOutlineIcon(label: 'التعقيم والحماية'),
            CategoryOutlineIcon(label: 'العناية الفموية'),
            CategoryOutlineIcon(label: 'مستلزمات الطلاب'),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(CategoryOutlineIcon), findsNWidgets(5));
  });
}
