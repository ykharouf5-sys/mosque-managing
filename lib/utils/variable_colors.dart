import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color.fromARGB(255, 21, 169, 188);
  static const Color primaryLight = Color(0xFF80CBC4);
  static const Color primarySurface = Color(0xFFE0F7FA);

  static const Color background = Color(0xFFF8FBFC);
  static const Color surface = Colors.white;

  static const Color textDark = Color(0xFF1E293B);
  static const Color textLight = Colors.white;
  static const Color textGray = Color(0xFF94A3B8);
  static const Color textGrey = Color(0xFF9E9E9E);
  static const Color textLightGray = Color(0xFFCBD5E1);

  static const Color divider = Color(0xFFE0E0E0);
  static const Color dividerLine = Color(0xFFE2EDF0);

  static const Color success = Color(0xFF4CAF50);
  static const Color pending = Color(0xFFFF9800);
  static const Color danger = Color(0xFFE53935);

  static const Color featureBg = Color(0xFFF0F6F8);
  static const Color dotDecor = Color.fromARGB(90, 21, 169, 188);

  // Auth-specific
  static const Color authBackground = Color(0xFFFFFFFF);
  static const Color authTextDark = Color(0xFF1A2B3C);
  static const Color authGrey = Color(0xFF8A9BAD);
  static const Color authFieldBg = Color(0xFFF4F9FA);
  static const Color authFieldBorder = Color(0xFFDDEEF0);
  static const Color authGoogleBg = Color(0xFFF5F5F5);
}

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double full = 90.0;
}

class AppShadows {
  static List<BoxShadow> get card => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get soft => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get nav => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, -2),
    ),
  ];

  static List<BoxShadow> get fab => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.25),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
}
