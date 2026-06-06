import 'package:flutter/material.dart';

/// Responsive theme and sizing constants
class ResponsiveTheme {
  /// Screen size categories
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1200;

  /// Default padding and margins
  static const double paddingXSmall = 4;
  static const double paddingSmall = 8;
  static const double paddingMedium = 16;
  static const double paddingLarge = 24;
  static const double paddingXLarge = 32;

  /// Default border radius
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusXLarge = 24;

  /// Font sizes — base values (will scale based on device)
  static const double fontSizeTiny = 10;
  static const double fontSizeSmall = 12;
  static const double fontSizeBody = 14;
  static const double fontSizeMedium = 16;
  static const double fontSizeLarge = 18;
  static const double fontSizeXLarge = 20;
  static const double fontSizeHeading = 24;
  static const double fontSizeTitle = 28;

  /// Icon sizes
  static const double iconSizeSmall = 16;
  static const double iconSizeMedium = 24;
  static const double iconSizeLarge = 32;
  static const double iconSizeXLarge = 48;

  /// Button heights
  static const double buttonHeightSmall = 36;
  static const double buttonHeightMedium = 48;
  static const double buttonHeightLarge = 56;

  /// Card dimensions
  static const double cardElevation = 4;
  static const double cardElevationHigh = 8;
}

/// Text styles — responsive
class ResponsiveTextStyles {
  static TextStyle headingStyle({
    required double screenWidth,
    Color color = Colors.black,
    FontWeight fontWeight = FontWeight.bold,
  }) {
    final fontSize = screenWidth < 600
        ? 24
        : screenWidth < 1200
        ? 28
        : 32;
    return TextStyle(
      fontSize: fontSize.toDouble(),
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextStyle subheadingStyle({
    required double screenWidth,
    Color color = Colors.grey,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    final fontSize = screenWidth < 600
        ? 16
        : screenWidth < 1200
        ? 18
        : 20;
    return TextStyle(
      fontSize: fontSize.toDouble(),
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextStyle bodyStyle({
    required double screenWidth,
    Color color = Colors.black87,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    final fontSize = screenWidth < 600
        ? 14
        : screenWidth < 1200
        ? 16
        : 18;
    return TextStyle(
      fontSize: fontSize.toDouble(),
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextStyle captionStyle({
    required double screenWidth,
    Color color = Colors.grey,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    final fontSize = screenWidth < 600
        ? 12
        : screenWidth < 1200
        ? 13
        : 14;
    return TextStyle(
      fontSize: fontSize.toDouble(),
      fontWeight: fontWeight,
      color: color,
    );
  }
}
