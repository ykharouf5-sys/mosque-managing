import 'package:dentalcare/auth/presentation/login_screen.dart';
import 'package:dentalcare/auth/presentation/onboarding_screen.dart';
import 'package:dentalcare/auth/presentation/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Widget _authPreview(Widget child) => ProviderScope(
  child: ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      home: Directionality(textDirection: TextDirection.rtl, child: child),
    ),
  ),
);

@Preview(name: 'Studentry — Onboarding', size: Size(393, 852))
Widget onboardingPreview() => _authPreview(const OnboardingScreen());

@Preview(name: 'Studentry — Login', size: Size(393, 852))
Widget loginPreview() => _authPreview(const LoginScreen());

@Preview(name: 'Studentry — Register', size: Size(393, 852))
Widget registerPreview() => _authPreview(const RegisterScreen());
