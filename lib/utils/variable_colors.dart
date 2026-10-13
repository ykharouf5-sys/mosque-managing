import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color.fromARGB(255, 17, 149, 167);
  static const Color primaryLight = Color(0xFFCCEBEE);
  static const Color primarySurface = Color(0xFFE8F6F7);
  static const Color primaryDark = Color(0xFF076F7E);
  static const Color onPrimary = Color(0xFF10202A);
  static const Color brandDeep = Color(0xFF164F59);

  static const Color background = primarySurface;
  static const Color surface = Colors.white;

  static const Color textDark = Color(0xFF193C44);
  static const Color textLight = Colors.white;
  static const Color textGray = Color(0xFF506C75);
  static const Color textGrey = textGray;
  static const Color textLightGray = Color(0xFF647E86);

  static const Color divider = Color(0xFFCDE3E7);
  static const Color dividerLine = divider;

  static const Color success = Color(0xFF4CAF50);
  static const Color pending = Color(0xFFFF9800);
  static const Color danger = Color(0xFFE53935);

  static const Color featureBg = Color(0xFFF3FAFB);
  static const Color dotDecor = Color.fromARGB(90, 21, 169, 188);

  // Auth-specific
  static const Color authBackground = primarySurface;
  static const Color authTextDark = textDark;
  static const Color authGrey = textGray;
  static const Color authFieldBg = surface;
  static const Color authFieldBorder = dividerLine;
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
