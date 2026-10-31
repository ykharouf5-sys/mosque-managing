import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/store/presentation/cart_screen.dart';
import 'package:studentry/store/presentation/providers/store_providers.dart';
import 'package:studentry/utils/app_theme.dart';

class ReviewCart extends CartNotifier {
  ReviewCart({this.quantity = 1});
  final int quantity;
  int removals = 0;
  @override
  CartState build() => CartState(
    items: [
      CartItem(
        product: Product.fromJson({
          'id': 'review-only',
          'name': 'مرآة أسنان',
          'price': 50,
          'description': '',
          'categoryId': '',
          'categoryName': '',
          'imageUrl': '',
          'createdAt': DateTime.utc(2026).toIso8601String(),
        }),
        quantity: quantity,
      ),
    ],
  );
  @override
  void removeFromCart(String productId) {
    removals++;
    state = state.copyWith(items: []);
  }

  @override
  void updateQuantity(String productId, int newQuantity) {
    state = state.copyWith(
      items: [
        CartItem(product: state.items.single.product, quantity: newQuantity),
      ],
    );
  }
}

Widget harness(ReviewCart cart) => ProviderScope(
  overrides: [cartProvider.overrideWith(() => cart)],
  child: ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (context, _) =>
        MaterialApp(theme: AppTheme.light(), home: const CartScreen()),
  ),
);

void main() {
  for (final useMinus in [false, true]) {
    testWidgets(
      '${useMinus ? 'minus at one' : 'remove icon'} asks before removing',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final cart = ReviewCart();
        await tester.pumpWidget(harness(cart));
        await tester.pumpAndSettle();
        final remove = useMinus
            ? find.byIcon(Icons.remove)
            : find.byTooltip('إزالة المنتج');
        await tester.tap(remove);
        await tester.pumpAndSettle();
        expect(
          find.text('هل تريد إزالة «مرآة أسنان» من السلة؟'),
          findsOneWidget,
        );
        expect(cart.removals, 0);
        await tester.tap(find.text('إلغاء'));
        await tester.pumpAndSettle();
        expect(cart.removals, 0);
        expect(find.text('مرآة أسنان'), findsOneWidget);
        await tester.tap(remove);
        await tester.pumpAndSettle();
        await tester.tap(find.text('تأكيد'));
        await tester.pumpAndSettle();
        expect(cart.removals, 1);
        expect(find.text('السلة فارغة'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('decreasing two items to one does not request removal', (
    tester,
  ) async {
    final cart = ReviewCart(quantity: 2);
    await tester.pumpWidget(harness(cart));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(cart.removals, 0);
    expect(find.text('1'), findsOneWidget);
  });
}
