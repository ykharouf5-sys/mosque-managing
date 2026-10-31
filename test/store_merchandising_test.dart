import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/store/presentation/store_merchandising.dart';

Product item(String id, String? year) => Product(
  id: id,
  name: id,
  description: '',
  imageUrl: '',
  categoryId: '',
  categoryName: '',
  price: 1,
  createdAt: DateTime(2026),
  academicYear: year,
);
void main() {
  test(
    'recommendations prioritize the real profile year without hiding products or changing the source',
    () {
      final source = [
        item('other', 'الأولى'),
        item('all', null),
        item('my-year', 'السنة الثالثة'),
        item('third-alias', 'third'),
      ];
      final ordered = recommendedStoreOrder(source, '3');
      expect(ordered.map((p) => p.id), [
        'my-year',
        'third-alias',
        'all',
        'other',
      ]);
      expect(source.first.id, 'other');
      expect(ordered.toSet(), source.toSet());
      expect(recommendedStoreOrder(source, null), source);
    },
  );
  test(
    '25 server products become five horizontal rows without duplicates or fabricated cards',
    () {
      final source = List.generate(25, (i) => item('$i', null));
      final rows = storeProductRows(source);
      expect(rows.length, 5);
      expect(rows.every((row) => row.length == 5), isTrue);
      expect(rows.expand((row) => row).toList(), source);
      expect(storeProductRows(source.take(3).toList()).single.length, 3);
      expect(storeProductRows([]), isEmpty);
    },
  );
}
