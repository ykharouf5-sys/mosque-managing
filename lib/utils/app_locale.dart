import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocale {
  static final ValueNotifier<Locale> localeNotifier = ValueNotifier(
    const Locale('ar'),
  );

  static Future<Locale> getSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_language');
    if (code != null) return Locale(code);
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    if (deviceLocale.languageCode == 'ar') return const Locale('ar');
    return const Locale('en');
  }

  static Future<void> setLocale(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', languageCode);
    localeNotifier.value = Locale(languageCode);
  }
}
