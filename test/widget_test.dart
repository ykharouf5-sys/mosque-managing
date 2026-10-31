// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:studentry/auth/presentation/login_screen.dart';
import 'package:studentry/auth/presentation/onboarding_screen.dart';
import 'package:studentry/auth/presentation/register_screen.dart';
import 'package:studentry/management/presentation/settings_screen.dart';
import 'package:studentry/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('application renders inside ProviderScope', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    // The welcome illustration intentionally animates continuously.
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification settings exposes an actionable reminder control', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const ProviderScope(
        child: ScreenUtilInit(
          designSize: Size(393, 852),
          child: MaterialApp(home: SettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('قفل التطبيق بالبصمة'), findsNothing);
    expect(find.text('المنبهات والتذكيرات'), findsOneWidget);
    final enableButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'تفعيل'),
    );
    expect(enableButton.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auth layouts fit compact phones without vertical scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> pumpAuth(Widget screen) async {
      await tester.pumpWidget(
        ProviderScope(
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            child: MaterialApp(home: screen),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              (widget.axisDirection == AxisDirection.down ||
                  widget.axisDirection == AxisDirection.up),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    }

    await pumpAuth(const RegisterScreen());
    await pumpAuth(const LoginScreen());
    await pumpAuth(const OnboardingScreen());
  });
}
