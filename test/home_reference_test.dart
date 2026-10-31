import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:studentry/shared/widgets/app_bottom_nav.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/student/data/subject_models.dart';
import 'package:studentry/student/presentation/home_dashboard_data.dart';
import 'package:studentry/student/presentation/student_home_screen.dart';
import 'package:studentry/student/presentation/widgets/home_dashboard_widgets.dart';
import 'package:studentry/utils/app_theme.dart';
import 'package:studentry/patients/data/patient_data.dart';
import 'package:studentry/patients/presentation/add_patient_screen.dart';
import 'package:studentry/utils/variable_colors.dart';

const _banner = PromoBanner(
  id: 'test-home',
  title: 'عنوان بانر المدير',
  subtitle: 'تفاصيل البانر',
  discountText: '',
  imageUrl: '',
  ctaText: 'افتح برنامجي',
  actionRoute: 'home:/schedule',
);

Widget _harness(
  Widget child, {
  double scale = 1,
  bool dark = false,
  bool? systemDark,
  List<Appointment> appointments = const [],
}) => ProviderScope(
  overrides: [
    homeTodayAppointmentsProvider.overrideWith((ref) async => appointments),
    homeTodayExpensesProvider.overrideWith((ref) async => 1250),
  ],
  child: ScreenUtilInit(
    designSize: const Size(393, 852),
    minTextAdapt: true,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark
          ? ThemeData(
              brightness: Brightness.dark,
              useMaterial3: true,
              fontFamily: 'ReviewArabic',
              colorSchemeSeed: AppColors.primary,
            )
          : AppTheme.light(fontFamily: 'ReviewArabic'),
      locale: const Locale('ar'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ar')],
      routes: {
        '/schedule': (_) => const Scaffold(body: Text('schedule destination')),
      },
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          platformBrightness: (systemDark ?? dark)
              ? Brightness.dark
              : Brightness.light,
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: child,
    ),
  ),
);

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
  });
  await tester.pump();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('build/home-dashboard-review').createSync(recursive: true);
    File(
      'build/home-dashboard-review/$name.png',
    ).writeAsBytesSync(png!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    final font = FontLoader('ReviewArabic');
    final optional = Platform.environment['REVIEW_FONT_PATH'];
    final path = optional ?? 'assets/fonts/NotoNaskhArabic-Regular.ttf';
    font.addFont(
      Future.value(ByteData.sublistView(File(path).readAsBytesSync())),
    );
    await font.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  test(
    'home placement survives cached round trip and leaves store routes intact',
    () {
      expect(PromoBanner.fromJson(_banner.toJson()).isHomeBanner, isTrue);
      expect(_banner.targetRoute, '/schedule');
      expect(PromoBanner.homeRoute('home:/store'), 'home:/store');
      final store = PromoBanner.fromJson({
        ..._banner.toJson(),
        'actionRoute': '/store',
      });
      expect(store.isHomeBanner, isFalse);
      expect(store.targetRoute, '/store');
    },
  );
  test(
    'real schedules count Arabic weekday variants without counting unscheduled subjects',
    () {
      StudentSubject subject(List<String> days) => StudentSubject(
        subjectId: '$days',
        name: '',
        code: '',
        academicYear: '',
        scheduleDays: days,
      );
      expect(
        todayLectureCount([
          subject(['الإثنين']),
          subject(['الاثنين']),
          subject(['الثلاثاء']),
          subject([]),
        ], DateTime(2026, 11, 2)),
        2,
      );
    },
  );
  test(
    'today spending includes confirmed orders and excludes cancelled pending and other days',
    () {
      final day = DateTime(2026, 10, 30);
      Order order(
        String id,
        OrderStatus status, {
        DateTime? date,
        bool offline = false,
      }) => Order(
        id: id,
        items: [],
        totalPrice: 25,
        status: status,
        createdAt: date ?? day,
        updatedAt: day,
        userId: 'test-only',
        awaitingSync: offline,
      );
      expect(
        confirmedTodayOrderTotal([
          order('1', OrderStatus.accepted),
          order('2', OrderStatus.delivered),
          order('3', OrderStatus.preparing),
          order('4', OrderStatus.pending),
          order('5', OrderStatus.cancelled),
          order('6', OrderStatus.rejected),
          order('7', OrderStatus.accepted, date: DateTime(2026, 10, 29)),
          order('8', OrderStatus.accepted, offline: true),
        ], day),
        75,
      );
    },
  );

  for (final width in [320.0, 360.0, 390.0, 430.0, 720.0]) {
    for (final scale in [1.0, 1.5]) {
      for (final dark in [false, true]) {
        testWidgets(
          'reference home $width scale $scale dark $dark has no overflow',
          (tester) async {
            tester.view.physicalSize = Size(width, 852);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final key = GlobalKey();
            await tester.pumpWidget(
              _harness(
                RepaintBoundary(
                  key: key,
                  child: const StudentHomeScreen(active: false),
                ),
                scale: scale,
                dark: dark,
              ),
            );
            await tester.pump(const Duration(milliseconds: 500));
            expect(tester.takeException(), isNull);
            expect(find.text('الوصول السريع'), findsNothing);
            expect(find.byType(HomeStat), findsNWidgets(4));
            final stats = find.byType(HomeStat);
            expect(
              tester.getTopLeft(stats.at(0)).dy,
              tester.getTopLeft(stats.at(1)).dy,
            );
            expect(
              tester.getTopLeft(stats.at(2)).dy,
              greaterThan(tester.getBottomRight(stats.at(0)).dy),
            );
            if (width == 390 && scale == 1) {
              await _capture(tester, key, dark ? 'home-dark' : 'home-light');
            }
            await tester.scrollUntilVisible(
              find.byKey(const ValueKey('home-add-patient')),
              150,
              scrollable: find.byType(Scrollable).first,
            );
            expect(
              find.byKey(const ValueKey('home-add-patient')),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          },
        );
      }
    }
  }
  for (final width in [320.0, 360.0, 384.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets(
        'patient action avoids appointment action at $width scale $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 852);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            _harness(
              const StudentHomeScreen(active: false),
              scale: scale,
              appointments: [
                Appointment(
                  time: '10:00',
                  patientName: 'Isolated layout fixture',
                  treatment: 'Checkup',
                  status: 'pending',
                  patientId: 'layout-only',
                  date: DateTime.now(),
                ),
              ],
            ),
          );
          await tester.pumpAndSettle();
          final text = find.text('إضافة موعد');
          await tester.scrollUntilVisible(
            text,
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          final appointment = find
              .ancestor(
                of: text,
                matching: find.byWidgetPredicate((w) => w is FilledButton),
              )
              .first;
          expect(
            tester
                .getRect(find.byKey(const ValueKey('home-add-patient')))
                .overlaps(tester.getRect(appointment)),
            isFalse,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('home and bottom bar follow app brand even when system is dark', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(const StudentHomeScreen(active: false), systemDark: true),
    );
    await tester.pump();
    final context = tester.element(find.byType(HomeHeader));
    expect(HomePalette.of(context).dark, isFalse);
    expect(HomePalette.teal, AppColors.primary);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
      AppColors.background,
    );
    for (final stat in tester.widgetList<HomeStat>(find.byType(HomeStat))) {
      expect(stat.color, AppColors.primary);
    }
    final selected = find.descendant(
      of: find.byKey(const ValueKey('bottom-nav-الرئيسية')),
      matching: find.byType(Icon),
    );
    expect(tester.widget<Icon>(selected).color, AppColors.primary);
  });
  testWidgets(
    'embedded and standalone home each expose one inline add patient action',
    (tester) async {
      await tester.pumpWidget(
        _harness(const StudentHomeScreen(active: false, embedded: true)),
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('home-add-patient')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('home-add-patient')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_harness(const StudentHomeScreen(active: false)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('home-add-patient')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -180));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('home-add-patient')).hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AddPatientScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'manager banner text and action are used without hard coded carousel dots',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          Scaffold(
            body: HomeBannerCarousel(
              banners: const [_banner],
              onAction: (banner) => Navigator.of(
                tester.element(find.byType(HomeBannerCarousel)),
              ).pushNamed(banner!.targetRoute),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('عنوان بانر المدير'), findsOneWidget);
      await tester.tap(find.text('افتح برنامجي'));
      await tester.pumpAndSettle();
      expect(find.text('schedule destination'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('long manager banner copy fits a narrow accessible layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _harness(
        Scaffold(
          body: ListView(
            children: [
              HomeBannerCarousel(
                banners: [
                  PromoBanner(
                    id: 'long-test',
                    title: List.filled(20, 'دراسة الأسنان').join(' '),
                    subtitle: List.filled(20, 'تنظيم المواعيد').join(' '),
                    discountText: '',
                    imageUrl: '',
                    ctaText: List.filled(8, 'ابدأ الآن').join(' '),
                    actionRoute: 'home:/schedule',
                  ),
                ],
                onAction: (_) {},
              ),
            ],
          ),
        ),
        scale: 1.5,
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Today empty and populated cards preserve add and appointment actions',
    (tester) async {
      var added = 0, opened = 0;
      await tester.pumpWidget(
        _harness(
          Scaffold(
            body: HomeTodayCard(
              appointments: const [],
              onAdd: () => added++,
              onAppointment: (_) => opened++,
            ),
          ),
        ),
      );
      expect(find.text('لا يوجد مواعيد اليوم'), findsOneWidget);
      await tester.tap(find.text('إضافة موعد'));
      expect(added, 1);
      final appt = Appointment(
        time: '10:00',
        patientName: 'اختبار معزول',
        treatment: 'متابعة',
        status: 'pending',
        patientId: 'fixture',
      );
      await tester.pumpWidget(
        _harness(
          Scaffold(
            body: HomeTodayCard(
              appointments: [appt],
              onAdd: () => added++,
              onAppointment: (_) => opened++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('اختبار معزول'));
      expect(opened, 1);
      expect(find.text('لا يوجد مواعيد اليوم'), findsNothing);
    },
  );
  testWidgets('bottom nav retains all five sections and callback indexes', (
    tester,
  ) async {
    var selected = -1;
    await tester.pumpWidget(
      _harness(
        Scaffold(
          bottomNavigationBar: AppBottomNav(
            selectedIndex: 0,
            onSelected: (i) => selected = i,
          ),
        ),
      ),
    );
    const labels = ['الرئيسية', 'المواعيد', 'جامعتي', 'المتجر', 'التقارير'];
    for (var i = 0; i < labels.length; i++) {
      await tester.tap(find.byKey(ValueKey('bottom-nav-${labels[i]}')));
      expect(selected, i);
    }
  });
}
