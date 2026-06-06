import 'package:flutter/material.dart';

class ResponsiveHelper {
  static late MediaQueryData _mediaQueryData;
  static late double screenWidth;
  static late double screenHeight;
  static late double horizontalBlock;
  static late double verticalBlock;
  
  static late double _safeAreaHorizontal;
  static late double _safeAreaVertical;
  static late double safeBlockHorizontal;
  static late double safeBlockVertical;

  void init(BuildContext context) {
    _mediaQueryData = MediaQuery.of(context);
    screenWidth = _mediaQueryData.size.width;
    screenHeight = _mediaQueryData.size.height;
    horizontalBlock = screenWidth / 100;
    verticalBlock = screenHeight / 100;

    _safeAreaHorizontal = _mediaQueryData.padding.left + _mediaQueryData.padding.right;
    _safeAreaVertical = _mediaQueryData.padding.top + _mediaQueryData.padding.bottom;
    safeBlockHorizontal = (screenWidth - _safeAreaHorizontal) / 100;
    safeBlockVertical = (screenHeight - _safeAreaVertical) / 100;
  }

  /// Relative width (0-100)
  static double w(double percentage) => horizontalBlock * percentage;

  /// Relative height (0-100)
  static double h(double percentage) => verticalBlock * percentage;

  /// Adaptive Font Size (using width as base)
  static double sp(double size) => horizontalBlock * (size / 3.75); // Based on 375px wide (standard iPhone)

  /// Check if device is tablet
  static bool isTablet(BuildContext context) => MediaQuery.of(context).size.width >= 600;
}
