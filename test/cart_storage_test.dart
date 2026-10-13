import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studentry/store/data/cart_storage.dart';
import 'package:studentry/store/data/store_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'cart survives storage reload, quantity edits and account separation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final product = Product.fromJson({
        'id': 'p1',
        'name': 'Book',
        'description': '',
        'imageUrl': '',
        'categoryId': '',
        'categoryName': '',
        'price': 10,
        'createdAt': DateTime.utc(2026).toIso8601String(),
      });
      final key = CartStorage.key('https://example.test', 'user-a');
      final item = CartItem(product: product, quantity: 1);
      final first = CartStorage.save(key, [item]);
      item.quantity = 3;
      final second = CartStorage.save(key, [item]);
      expect((await CartStorage.load(key)).single.quantity, 3);
      await Future.wait([first, second]);
      expect((await CartStorage.load(key)).single.quantity, 3);
      expect(
        await CartStorage.load(
          CartStorage.key('https://example.test', 'user-b'),
        ),
        isEmpty,
      );
      await CartStorage.save(key, []);
      expect(await CartStorage.load(key), isEmpty);
    },
  );
}
