import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/store/presentation/product_purchase_bar.dart';

void main() {
  testWidgets('purchase bar changes quantity and disables sold-out purchase', (
    tester,
  ) async {
    var quantity = 1;
    var added = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            bottomNavigationBar: ProductPurchaseBar(
              quantity: quantity,
              inStock: true,
              onDecrease: () => quantity--,
              onIncrease: () => quantity++,
              onAdd: () => added++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('زيادة الكمية'));
    await tester.tap(find.text('أضف للسلة'));
    expect(quantity, 2);
    expect(added, 1);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: ProductPurchaseBar(
            quantity: 1,
            inStock: false,
            onDecrease: null,
            onIncrease: null,
            onAdd: null,
          ),
        ),
      ),
    );
    expect(find.text('غير متوفر'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });
}
