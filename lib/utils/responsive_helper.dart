import 'package:flutter/material.dart';

/// Helper class for responsive design across all screen sizes
class ResponsiveHelper {
  final BuildContext context;
  final Size screenSize;
  final double screenWidth;
  final double screenHeight;
  final bool isMobile;
  final bool isTablet;
  final bool isDesktop;

  ResponsiveHelper(this.context)
    : screenSize = MediaQuery.of(context).size,
      screenWidth = MediaQuery.of(context).size.width,
      screenHeight = MediaQuery.of(context).size.height,
      isMobile = MediaQuery.of(context).size.width < 600,
      isTablet =
          MediaQuery.of(context).size.width >= 600 &&
          MediaQuery.of(context).size.width < 1200,
      isDesktop = MediaQuery.of(context).size.width >= 1200;

  /// العرض النسبي من شاشة الجهاز
  double width(double percentage) => screenWidth * (percentage / 100);

  /// الارتفاع النسبي من شاشة الجهاز
  double height(double percentage) => screenHeight * (percentage / 100);

  /// حجم الخط متجاوب — صغير للموبايل، كبير للتابلت
  double fontSize(double mobile, {double? tablet, double? desktop}) {
    if (isMobile) return mobile;
    if (isTablet) return tablet ?? mobile * 1.2;
    return desktop ?? mobile * 1.5;
  }

  /// Padding متجاوب
  EdgeInsetsGeometry padding(double mobile, {double? tablet, double? desktop}) {
    final value = isMobile
        ? mobile
        : (isTablet ? (tablet ?? mobile * 1.2) : (desktop ?? mobile * 1.5));
    return EdgeInsets.all(value);
  }

  /// Padding متجاوب — symmetric
  EdgeInsetsGeometry paddingSymmetric({
    required double mobileHorizontal,
    required double mobileVertical,
    double? tabletHorizontal,
    double? tabletVertical,
    double? desktopHorizontal,
    double? desktopVertical,
  }) {
    final h = isMobile
        ? mobileHorizontal
        : (isTablet
              ? (tabletHorizontal ?? mobileHorizontal * 1.2)
              : (desktopHorizontal ?? mobileHorizontal * 1.5));
    final v = isMobile
        ? mobileVertical
        : (isTablet
              ? (tabletVertical ?? mobileVertical * 1.2)
              : (desktopVertical ?? mobileVertical * 1.5));
    return EdgeInsets.symmetric(horizontal: h, vertical: v);
  }

  /// عرض العمود في الجدول متجاوب
  double tableColumnWidth() {
    if (isMobile) return screenWidth / 3.5;
    if (isTablet) return screenWidth / 4;
    return screenWidth / 5;
  }

  /// عدد الأعمدة في GridView متجاوب
  int gridCrossAxisCount() {
    if (isMobile) return 2;
    if (isTablet) return 3;
    return 4;
  }

  /// حجم Icon متجاوب
  double iconSize() {
    if (isMobile) return 24;
    if (isTablet) return 32;
    return 40;
  }

  /// حجم Button متجاوب
  Size buttonSize() {
    if (isMobile) return const Size(double.infinity, 48);
    if (isTablet) return Size(screenWidth * 0.7, 56);
    return Size(screenWidth * 0.5, 60);
  }

  /// Border radius متجاوب
  double borderRadius() {
    if (isMobile) return 8;
    if (isTablet) return 12;
    return 16;
  }

  /// قيمة SizedBox.height متجاوبة
  double verticalSpace() {
    if (isMobile) return 8;
    if (isTablet) return 12;
    return 16;
  }

  /// قيمة SizedBox.width متجاوبة
  double horizontalSpace() {
    if (isMobile) return 8;
    if (isTablet) return 12;
    return 16;
  }

  /// حجم Card متجاوب (width)
  double cardWidth() {
    if (isMobile) return screenWidth * 0.9;
    if (isTablet) return screenWidth * 0.8;
    return screenWidth * 0.6;
  }

  /// Aspect ratio للصور متجاوب
  double imageAspectRatio() => 16 / 9;

  /// حجم Avatar متجاوب
  double avatarRadius() {
    if (isMobile) return 24;
    if (isTablet) return 32;
    return 40;
  }

  /// العرض الآمن (Safe Area) يؤخذ بعين الاعتبار
  double safeWidth() =>
      screenWidth -
      MediaQuery.of(context).padding.left -
      MediaQuery.of(context).padding.right;

  /// الارتفاع الآمن
  double safeHeight() =>
      screenHeight -
      MediaQuery.of(context).padding.top -
      MediaQuery.of(context).padding.bottom;

  /// Orientation (عمودي أم أفقي)
  bool isPortrait() =>
      MediaQuery.of(context).orientation == Orientation.portrait;

  bool isLandscape() =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  /// Pixel density (DPI)
  double pixelDensity() => MediaQuery.of(context).devicePixelRatio;
}

/// Extension على BuildContext للوصول السريع
extension ResponsiveExt on BuildContext {
  ResponsiveHelper get responsive => ResponsiveHelper(this);
}
