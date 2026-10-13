import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/store/presentation/widgets/delivery_location_field.dart';

void main() {
  testWidgets('address field opens map picker and can clear a selected point', (
    tester,
  ) async {
    var opened = 0;
    var cleared = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: DeliveryLocationField(
              latitude: 33.5138,
              longitude: 36.2765,
              onChooseLocation: () => opened++,
              onClearLocation: () => cleared++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('choose-delivery-location')));
    await tester.tap(find.byTooltip('إزالة الموقع المحدد'));
    expect(opened, 1);
    expect(cleared, 1);
  });

  test('order keeps delivery coordinates through local and server JSON', () {
    final order = Order(
      id: 'order-1',
      items: const [],
      totalPrice: 0,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      userId: 'buyer',
      locationLatitude: 33.5138,
      locationLongitude: 36.2765,
    );

    expect(Order.fromJson(order.toJson()).locationLatitude, 33.5138);
    final serverJson = Map<String, dynamic>.from(order.toJson())
      ..remove('locationLatitude')
      ..remove('locationLongitude')
      ..['location_latitude'] = 33.5138
      ..['location_longitude'] = 36.2765;
    final restored = Order.fromJson(serverJson);
    expect(restored.locationLatitude, 33.5138);
    expect(restored.locationLongitude, 36.2765);
  });
}
