import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/student/data/subject_models.dart';

void main() {
  group('remote academic models', () {
    test('subject preserves server version and lecture payload', () {
      final subject = Subject.fromJson({
        'id': 'subject-1',
        'name': 'Algorithms',
        'code': 'CS-201',
        'academicYear': 'second',
        'totalLectures': 2,
        'version': 7,
        'lectures': [
          {
            'number': 1,
            'title': 'Sorting',
            'links': ['https://example.test/lecture'],
          },
        ],
      });

      expect(subject.version, 7);
      expect(subject.totalLectures, 2);
      expect(subject.lectures.single.links.single, contains('lecture'));
      expect(subject.toJson()['version'], 7);
    });

    test('enrollment keeps its own identifier and optimistic version', () {
      final enrollment = StudentSubject.fromJson({
        'enrollmentId': 'enrollment-1',
        'subjectId': 'subject-1',
        'name': 'Databases',
        'code': 'CS-301',
        'academicYear': 'third',
        'viewedLectures': [1, 3],
        'totalLectures': 10,
        'grade': 84.6,
        'version': 4,
      });

      expect(enrollment.enrollmentId, 'enrollment-1');
      expect(enrollment.viewedLectures, [1, 3]);
      expect(enrollment.grade, 85);
      expect(enrollment.version, 4);
    });
  });

  group('remote store models', () {
    test('product and coupon preserve server-calculated fields', () {
      final product = Product.fromJson({
        'id': 'product-1',
        'name': 'Reference',
        'brand': 'Studentry Press',
        'description': 'Book',
        'imageUrl': 'https://example.test/book.webp',
        'categoryId': 'category-1',
        'categoryName': 'Books',
        'price': 20,
        'rating': 4.5,
        'reviewsCount': 3,
        'stock': 8,
        'createdAt': '2026-08-24T00:00:00Z',
        'academicYear': 'second',
        'deliveryPrice': 2.5,
      });
      final coupon = Coupon.fromJson({
        'id': 'coupon-1',
        'code': 'SAVE10',
        'description': 'Ten percent',
        'discountType': 'percentage',
        'discountValue': 10,
        'minPurchase': 20,
        'isActive': true,
      });

      expect(product.deliveryPrice, 2.5);
      expect(product.reviewsCount, 3);
      expect(coupon.discountValue, 10);
      expect(coupon.minPurchase, 20);
    });
  });
}
