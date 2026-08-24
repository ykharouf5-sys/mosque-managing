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
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('app lock keeps the protected navigator subtree mounted', (
    tester,
  ) async {
    _LifecycleProbeState.disposeCount = 0;

    Widget buildApp(bool showLock) => MaterialApp(
      home: AppLockOverlay(
        showLock: showLock,
        lockStateReady: true,
        unlockInProgress: false,
        onUnlock: () {},
        onSignOut: () {},
        child: const _LifecycleProbe(),
      ),
    );

    await tester.pumpWidget(buildApp(false));
    await tester.pumpWidget(buildApp(true));
    expect(find.byType(_LifecycleProbe), findsOneWidget);
    expect(_LifecycleProbeState.disposeCount, 0);

    await tester.pumpWidget(buildApp(false));
    expect(find.byType(_LifecycleProbe), findsOneWidget);
    expect(_LifecycleProbeState.disposeCount, 0);
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

    expect(find.text('المنبهات والتذكيرات'), findsOneWidget);
    final enableButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'تفعيل'),
    );
    expect(enableButton.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fixed auth layouts fit a compact phone without scrolling', (
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
      await tester.pumpAndSettle();
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

class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe();

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  static int disposeCount = 0;

  @override
  void dispose() {
    disposeCount++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
