import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/providers/auth_provider.dart';
import 'package:studentry/shared/widgets/app_drawer.dart';
import 'package:studentry/student/data/academic_document_service.dart';
import 'package:studentry/student/data/academic_year.dart';
import 'package:studentry/student/data/subject_models.dart';
import 'package:studentry/student/presentation/widgets/home_dashboard_widgets.dart';
import 'package:studentry/student/presentation/academic_content_editor.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/store/presentation/widgets/store_product_card.dart';
import 'package:studentry/patients/presentation/store_purchase_report.dart';
import 'package:studentry/utils/app_theme.dart';

class _DelayedLogout extends AuthNotifier {
  final done = Completer<void>();
  int calls = 0;
  @override
  AuthState build() =>
      const AuthState(userId: 'u', role: 'student', isLoggedIn: true);
  @override
  Future<void> logout() async {
    calls++;
    await done.future;
    state = const AuthState();
  }
}

Widget _app(
  Widget child, {
  List<Override> overrides = const [],
  double scale = 1,
}) => ProviderScope(
  overrides: overrides,
  child: ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (_, child) => MaterialApp(
      theme: AppTheme.light(),
      routes: {
        '/login': (_) => const Scaffold(body: Text('login destination')),
      },
      builder: (context, content) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: content!,
        ),
      ),
      home: child,
    ),
    child: child,
  ),
);

Product _product() => Product(
  id: 'p',
  name: 'جهاز تنظيف الأسنان الاحترافي للاستخدام السريري مع كامل الملحقات',
  brand: '',
  description: '',
  imageUrl: '',
  categoryId: 'c',
  categoryName: '',
  price: 1250000,
  rating: 4.5,
  reviewsCount: 1,
  stock: 1,
  createdAt: DateTime(2026),
);
Order _order(OrderStatus status, {DateTime? date}) => Order(
  id: status.name,
  items: [CartItem(product: _product(), quantity: 2)],
  totalPrice: 1000,
  status: status,
  createdAt: date ?? DateTime.now(),
  updatedAt: DateTime.now(),
  userId: 'u',
);

void main() {
  testWidgets(
    'manager adds one lecture or a summary, without bulk generation or empty publication',
    (tester) async {
      await tester.pumpWidget(
        _app(
          AcademicContentEditor(
            subject: Subject(
              id: 's',
              name: 'المادة',
              code: 'A',
              academicYear: 'third',
              totalLectures: 0,
            ),
          ),
        ),
      );
      expect(find.text('المحاضرات المنشورة: 0'), findsOneWidget);
      await tester.tap(find.text('إضافة محاضرة واحدة'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'المحاضرة الأولى',
      );
      await tester.ensureVisible(find.text('حفظ ونشر'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ ونشر'));
      await tester.pump();
      expect(
        find.text('أضف ملف PDF أو HTML أو رابط المحتوى قبل النشر.'),
        findsOneWidget,
      );
      expect(find.text('حفظ ونشر'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'profile year aliases keep third year instead of falling back to first',
    () {
      for (final year in ['third', '3', '٣', 'الثالثة', 'السنة الثالثة']) {
        expect(academicYearLabel(year), 'الثالثة');
      }
      expect(academicYearLabel(null), '');
    },
  );
  test(
    'lecture PDFs, HTML and summary kinds survive local cache round trips',
    () {
      final subject = Subject.fromJson({
        'id': 's',
        'name': 'المادة',
        'code': 'A',
        'academicYear': 'third',
        'lectures': [
          {
            'number': 1,
            'title': 'محاضرة',
            'pdfReference': 'academic/u/documents/l.pdf',
            'pdfUrl': 'https://files.test/signed',
          },
        ],
        'resources': [
          {
            'number': 501,
            'title': 'ملخص',
            'kind': 'summary',
            'pdfReference': 'https://files.test/summary.html',
          },
        ],
      });
      final cached = Subject.fromJson(subject.toJson());
      expect(cached.publishedLectures.length, 1);
      expect(cached.resources.single.kind, 'summary');
      expect(
        cached.publishedLectures.single.pdfReference,
        'academic/u/documents/l.pdf',
      );
      expect(cached.resources.single.pdfReference, endsWith('.html'));
    },
  );
  test(
    'opening a lecture renews that lecture document rather than the subject PDF',
    () async {
      var calls = 0;
      final service = AcademicDocumentService(
        client: ApiClient.forTesting(
          MockClient((r) async {
            expect(r.url.path, endsWith('/subjects/s/lectures/2/document-url'));
            return http.Response(
              jsonEncode({
                'data': {
                  'url': 'https://files.test/two.pdf?version=${++calls}',
                },
              }),
              200,
            );
          }),
        ),
      );
      final lecture = SubjectLecture(
        number: 2,
        pdfReference: 'academic/u/documents/l.pdf',
      );
      expect((await service.lectureUrl('s', lecture)).query, 'version=1');
      expect((await service.lectureUrl('s', lecture)).query, 'version=2');
    },
  );
  test(
    'store purchases exclude pending cancelled rejected and local writes',
    () {
      expect(
        OrderStatus.values.where((s) => isConfirmedPurchase(_order(s))).length,
        4,
      );
      expect(
        isConfirmedPurchase(
          Order(
            id: 'offline',
            items: [],
            totalPrice: 1000,
            userId: 'u',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            status: OrderStatus.accepted,
            awaitingSync: true,
          ),
        ),
        isFalse,
      );
    },
  );
  testWidgets(
    'drawer logout reaches login after first tap even after the drawer disposes',
    (tester) async {
      final auth = _DelayedLogout();
      await tester.pumpWidget(
        _app(
          Scaffold(
            drawer: const AppDrawer(),
            appBar: AppBar(),
            body: const Text('home'),
          ),
          overrides: [authProvider.overrideWith(() => auth)],
        ),
      );
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('تسجيل خروج'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('تسجيل خروج'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(auth.calls, 1);
      auth.done.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('login destination'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'home keeps logo separate from menu and profile settings action',
    (tester) async {
      var menu = 0, settings = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: HomeHeader(
              name: 'الطبيب الحقيقي',
              reminders: 0,
              onProfile: () => settings++,
              onNotifications: () {},
              onMenu: () => menu++,
            ),
          ),
        ),
      );
      expect(find.text('أهلاً بعودتك'), findsNothing);
      expect(find.text('طبيب أسنان'), findsOneWidget);
      await tester.tap(find.byTooltip('القائمة الجانبية'));
      expect(menu, 1);
      await tester.tap(find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == 'الإعدادات'));
      expect(settings, 1);
    },
  );
  for (final scale in [1.0, 1.5]) {
    testWidgets('product name and price fit a narrow card at scale $scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Center(
              child: SizedBox(
                width: 136,
                height: 240 * scale,
                child: StoreProductCard(product: _product(), onTap: () {}),
              ),
            ),
          ),
          scale: scale,
        ),
      );
      expect(find.text(_product().name), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'purchase report filters periods and expands actual order line items',
    (tester) async {
      final now = DateTime.now();
      final data = [
        _order(OrderStatus.accepted),
        _order(OrderStatus.cancelled),
        _order(OrderStatus.delivered, date: DateTime(now.year - 1)),
      ];
      await tester.pumpWidget(
        _app(
          const Scaffold(body: StorePurchaseReport()),
          overrides: [
            storePurchaseReportProvider.overrideWith((ref) async => data),
          ],
        ),
      );
      await tester.pump();
      expect(find.byType(ExpansionTile), findsOneWidget);
      await tester.tap(find.byType(ExpansionTile));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(_product().name), findsOneWidget);
      await tester.tap(find.text('الكل'));
      await tester.pump();
      expect(find.byType(ExpansionTile), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
