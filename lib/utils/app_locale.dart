import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocale {
  static final ValueNotifier<Locale> localeNotifier = ValueNotifier(
    const Locale('ar'),
  );

  static Future<Locale> getSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    return Locale(prefs.getString('app_language') == 'en' ? 'en' : 'ar');
  }

  static Future<void> setLocale(String languageCode) async {
    if (!['ar', 'en'].contains(languageCode)) {
      throw ArgumentError.value(languageCode, 'languageCode');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', languageCode);
    localeNotifier.value = Locale(languageCode);
  }

  static String get language => localeNotifier.value.languageCode;
  static String text(String ar, String en) => language == 'en' ? en : ar;
  static String catalogText(
    Map<String, Map<String, String>> translations,
    String field,
    String fallback,
  ) {
    final value = translations[language]?[field];
    if (value != null && value.trim().isNotEmpty) return value;
    final arabic = translations['ar']?[field];
    return arabic != null && arabic.trim().isNotEmpty ? arabic : fallback;
  }
}
