import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/student/data/academic_year.dart';

/// Presentation order only. Every product on the current API page remains reachable.
List<Product> recommendedStoreOrder(List<Product> products, String? year) {
  final normalized = academicYearLabel(year);
  if (normalized.isEmpty) return List<Product>.of(products);
  int priority(Product product) {
    final productYear = academicYearLabel(product.academicYear);
    if (productYear == normalized) return 0;
    return productYear.isEmpty ? 1 : 2;
  }

  // Stable partitions keep the server order within each recommendation group.
  return [
    for (var group = 0; group < 3; group++)
      ...products.where((product) => priority(product) == group),
  ];
}

List<List<Product>> storeProductRows(List<Product> products) => [
  for (var start = 0; start < products.length; start += 5)
    products.sublist(start, (start + 5).clamp(0, products.length)),
];
