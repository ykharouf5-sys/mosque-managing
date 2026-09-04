import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:studentry/patients/presentation/appointments_screen.dart';
import 'package:studentry/shared/widgets/app_bottom_nav.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  Future<void> setViewport(WidgetTester tester, Size size, Widget child) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          child: MaterialApp(home: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('appointments calendar fits compact and tablet widths', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in [const Size(320, 700), const Size(800, 1000)]) {
      await setViewport(tester, size, const AppointmentsScreen(embedded: true));
      expect(
        find.byKey(const ValueKey('appointments-calendar-grid')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('calendar-day-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('bottom navigation distributes all destinations evenly', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await setViewport(
      tester,
      const Size(320, 700),
      const Scaffold(bottomNavigationBar: AppBottomNav(selectedIndex: 1)),
    );

    const labels = ['الرئيسية', 'المواعيد', 'جامعتي', 'المتجر', 'التقارير'];
    final widths = labels
        .map(
          (label) =>
              tester.getSize(find.byKey(ValueKey('bottom-nav-$label'))).width,
        )
        .toList();
    for (final width in widths.skip(1)) {
      expect(width, closeTo(widths.first, 0.01));
    }
    expect(tester.takeException(), isNull);
  });
}
