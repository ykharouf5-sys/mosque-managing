import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/store/data/store_api_service.dart';
import 'package:studentry/store/data/store_models.dart';

void main() {
  test(
    'private source survives manager catalog mapping and cached round trip',
    () {
      final row = <String, dynamic>{
        'id': 'product',
        'name': 'Tool',
        'source_name': 'Supplier A',
        'price': '10.00',
        'stock': 4,
        'is_available': true,
        'created_at': '2026-10-14T00:00:00Z',
      };
      final product = Product.fromJson(StoreApiService.rowToProductMap(row));
      expect(Product.fromJson(product.toJson()).sourceName, 'Supplier A');
      row.remove('source_name');
      final publicProduct = Product.fromJson(
        StoreApiService.rowToProductMap(row),
      );
      expect(publicProduct.sourceName, isNull);
      expect(publicProduct.toJson().containsKey('sourceName'), isFalse);
    },
  );

  test(
    'manager orders retain trusted buyer, supplier and purchase-time price',
    () {
      final order = Order.fromJson(
        StoreApiService.rowToOrderMap({
          'id': 'order',
          'user_id': 'buyer',
          'status': 'pending',
          'total': '23.00',
          'created_at': '2026-10-14T00:00:00Z',
          'updated_at': '2026-10-14T00:00:00Z',
          'customer': {
            'full_name': 'Verified buyer',
            'email': 'buyer@example.invalid',
            'phone': '0912345678',
            'university': 'University',
          },
          'details': {
            'doctorName': 'Untrusted submitted name',
            'shipping_address': 'Delivery address',
            'phone': '0987654321',
            'clinic_address': 'Clinic address',
            'doctor_governorate': 'Governorate',
            'location_latitude': 33.5,
            'location_longitude': 36.3,
          },
          'items': [
            {
              'product': {
                'id': 'product',
                'name': 'Tool',
                'brand': 'Brand',
                'description': 'Description',
                'price': '10.00',
              },
              'quantity': 2,
              'product_source_name': 'Supplier A',
            },
          ],
        }),
      );
      expect(order.doctorName, 'Verified buyer');
      expect(order.doctorPhone, '0912345678');
      expect(order.phone, '0987654321');
      expect(order.clinicAddress, 'Clinic address');
      expect(order.doctorGovernorate, 'Governorate');
      expect(order.locationLatitude, 33.5);
      expect(order.locationLongitude, 36.3);
      expect(order.customer['email'], 'buyer@example.invalid');
      expect(order.items.single.product.sourceName, 'Supplier A');
      expect(order.items.single.product.price, 10);
      expect(order.items.single.product.description, 'Description');
      expect(
        Order.fromJson(order.toJson()).customer['university'],
        'University',
      );
    },
  );
}
