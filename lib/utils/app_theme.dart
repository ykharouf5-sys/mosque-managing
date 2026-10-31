import 'package:flutter/material.dart';
import 'variable_colors.dart';

/// Shared surfaces keep records white against the soft cyan app background.
class AppTheme {
  static ThemeData light({
    String? fontFamily,
    double fontSize = 16,
    double titleSize = 18,
    double fieldSize = 14,
    EdgeInsets buttonPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
    EdgeInsets inputPadding = const EdgeInsets.symmetric(
      horizontal: 18,
      vertical: 16,
    ),
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primarySurface,
      onPrimaryContainer: AppColors.textDark,
      secondary: AppColors.primaryDark,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.primarySurface,
      onSecondaryContainer: AppColors.textDark,
      surface: AppColors.surface,
      onSurface: AppColors.textDark,
      onSurfaceVariant: AppColors.textGray,
      outline: AppColors.dividerLine,
      brightness: Brightness.light,
    );
    final textStyle = TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      height: 1.35,
      leadingDistribution: TextLeadingDistribution.even,
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: titleSize,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          minimumSize: const Size(64, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: shape,
          padding: buttonPadding,
          textStyle: textStyle,
          alignment: Alignment.center,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size(64, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: shape,
          padding: buttonPadding,
          textStyle: textStyle,
          alignment: Alignment.center,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          backgroundColor: AppColors.surface,
          minimumSize: const Size(64, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: shape,
          side: const BorderSide(color: AppColors.dividerLine),
          padding: buttonPadding,
          textStyle: textStyle,
          alignment: Alignment.center,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          minimumSize: const Size(48, 44),
          tapTargetSize: MaterialTapTargetSize.padded,
          padding: buttonPadding,
          shape: shape,
          alignment: Alignment.center,
          textStyle: textStyle.copyWith(fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: inputPadding,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.dividerLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(
            color: AppColors.primaryDark,
            width: 1.5,
          ),
        ),
        hintStyle: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textGray,
          fontSize: fieldSize,
        ),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textGray,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.dividerLine),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primarySurface,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: fontFamily,
            color: AppColors.textDark,
            fontSize: 12,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primarySurface,
        checkmarkColor: AppColors.primaryDark,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.textDark,
        ),
        side: const BorderSide(color: AppColors.dividerLine),
        shape: shape,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dividerLine,
        thickness: 1,
      ),
    );
  }
}
