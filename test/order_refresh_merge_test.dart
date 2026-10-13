import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/store/presentation/providers/store_providers.dart';

Order order(
  String id,
  int day, {
  OrderStatus status = OrderStatus.pending,
  int update = 1,
}) => Order(
  id: id,
  userId: 'synthetic',
  items: [],
  totalPrice: 1,
  status: status,
  createdAt: DateTime(2026, 10, day),
  updatedAt: DateTime(2026, 10, update),
);

void main() {
  test(
    'delta keeps loaded history, updates old-page status, deduplicates new pages',
    () {
      final history = [for (var i = 1; i <= 40; i++) order('$i', i)];
      final updates = [
        order('2', 2, status: OrderStatus.delivered, update: 3),
        order('41', 41, update: 3),
      ];
      final merged = mergeConfirmedOrderUpdates(history, updates);
      expect(merged.length, 41);
      expect(merged.first.id, '41');
      expect(
        merged.singleWhere((value) => value.id == '2').status,
        OrderStatus.delivered,
      );
      expect(mergeConfirmedOrderUpdates(merged, updates).length, 41);
    },
  );

  test('late stale page does not overwrite a newer delta', () {
    final delivered = order('1', 1, status: OrderStatus.delivered, update: 3);
    expect(
      mergeConfirmedOrderUpdates([delivered], [order('1', 1)]).single.status,
      OrderStatus.delivered,
    );
  });

  test('empty delta does not reset pagination contents', () {
    final history = [for (var i = 1; i <= 40; i++) order('$i', i)];
    expect(mergeConfirmedOrderUpdates(history, []).length, 40);
  });
}
