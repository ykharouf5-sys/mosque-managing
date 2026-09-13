import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/store/data/store_api_service.dart';
import 'package:studentry/store/data/store_models.dart';

void main() {
  test('maps Laravel order decimals and nested product snapshots', () {
    final mapped = StoreApiService.rowToOrderMap({
      'id': '10000000-0000-0000-0000-000000000001',
      'user_id': '20000000-0000-0000-0000-000000000001',
      'total': '20.00',
      'status': 'approved',
      'created_at': '2026-09-13T10:00:00Z',
      'updated_at': '2026-09-13T10:05:00Z',
      'items': [
        {
          'product': {'id': 'p-1', 'name': 'Book', 'price': '10.00'},
          'quantity': 2,
          'line_total': '20.00',
        },
      ],
      'details': <String, dynamic>{},
    });

    expect(mapped['totalPrice'], 20.0);
    expect(
      orderStatusFromWire(mapped['status']?.toString()),
      OrderStatus.accepted,
    );
    final item = CartItem.fromJson(
      Map<String, dynamic>.from((mapped['items'] as List).single as Map),
    );
    expect(item.product.id, 'p-1');
    expect(item.product.name, 'Book');
    expect(item.product.price, 10.0);
    expect(item.quantity, 2);
  });

  test('keeps rejected and cancelled order results distinct', () {
    expect(orderStatusFromWire('rejected'), OrderStatus.rejected);
    expect(orderStatusFromWire('cancelled'), OrderStatus.cancelled);
  });
}
