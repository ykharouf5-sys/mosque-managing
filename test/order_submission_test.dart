import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/store/data/store_api_service.dart';
import 'package:studentry/store/presentation/providers/store_providers.dart';
import 'package:studentry/store/presentation/widgets/order_submission_notice.dart';

void main() {
  final product = Product.fromJson({
    'id': 'p1',
    'name': 'Test',
    'price': 100.25,
    'deliveryPrice': 7.5,
    'brand': '',
    'description': '',
    'imageUrl': '',
    'categoryId': '',
    'categoryName': '',
    'stock': 10,
    'rating': 0,
    'reviewsCount': 0,
    'createdAt': '2026-10-01T00:00:00Z',
  });
  test('cart includes per-unit delivery and authoritative order aliases', () {
    final cart = CartState(items: [CartItem(product: product, quantity: 2)]);
    expect(cart.deliveryTotal, 15);
    expect(cart.grandTotal, 215.5);
    final order = StoreApiService.rowToOrderMap({
      'id': 'o1',
      'items': [],
      'total': '215.50',
      'status': 'pending',
      'created_at': '2026-10-01T00:00:00Z',
      'user_id': 'u1',
      'details': {
        'delivery_price': '15.00',
        'totalPrice': 1,
        'awaitingSync': true,
      },
    });
    expect(order['totalPrice'], 215.5);
    expect(order['deliveryPrice'], 15);
    expect(order['awaitingSync'], false);
  });
  test(
    'queued orders survive server refresh and confirmed server data wins',
    () {
      final queued = Order(
        id: 'o1',
        items: [],
        totalPrice: 215.5,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        userId: 'u1',
        awaitingSync: true,
      );
      final local = [
        {'data': jsonEncode(queued.toJson())},
      ];
      expect(mergeOrderSnapshots([], local).single.awaitingSync, true);
      final confirmed = Order.fromJson({
        ...queued.toJson(),
        'awaitingSync': false,
        'totalPrice': 220,
      });
      final merged = mergeOrderSnapshots([confirmed], local);
      expect(merged.length, 1);
      expect(merged.single.awaitingSync, false);
      expect(merged.single.totalPrice, 220);
    },
  );
  testWidgets('queued checkout never claims successful transmission', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: OrderSubmissionNotice(awaitingSync: true)),
        ),
      ),
    );
    expect(find.textContaining('بانتظار الإرسال'), findsOneWidget);
    expect(find.text('تم إرسال الطلب بنجاح'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
