import 'package:flutter/services.dart';

/// Presentation constraints only. Required/optional validators stay at call sites.
abstract final class AppInputFormatters {
  static final TextInputFormatter normalizeDigits =
      TextInputFormatter.withFunction((oldValue, newValue) {
        if (!newValue.composing.isCollapsed) return newValue;
        final text = newValue.text.replaceAllMapped(RegExp('[٠-٩۰-۹]'), (
          match,
        ) {
          final code = match[0]!.codeUnitAt(0);
          return '${code >= 0x06F0 ? code - 0x06F0 : code - 0x0660}';
        });
        return newValue.copyWith(text: text);
      });

  static List<TextInputFormatter> integer({int digits = 7, int? max}) => [
    normalizeDigits,
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(digits),
    if (max != null)
      TextInputFormatter.withFunction((oldValue, newValue) {
        if (!newValue.composing.isCollapsed || newValue.text.isEmpty) {
          return newValue;
        }
        final value = int.tryParse(newValue.text);
        return value != null && value <= max ? newValue : oldValue;
      }),
  ];

  static List<TextInputFormatter> decimal({int digits = 10, int places = 2}) =>
      [
        normalizeDigits,
        TextInputFormatter.withFunction((oldValue, newValue) {
          if (!newValue.composing.isCollapsed) return newValue;
          final normalized = newValue.text.replaceAll('٫', '.');
          final pattern = RegExp('^\\d{0,$digits}(?:\\.\\d{0,$places})?\$');
          return pattern.hasMatch(normalized)
              ? newValue.copyWith(text: normalized)
              : oldValue;
        }),
      ];

  static List<TextInputFormatter> get phone => [
    normalizeDigits,
    TextInputFormatter.withFunction((oldValue, newValue) {
      if (!newValue.composing.isCollapsed) return newValue;
      return RegExp(r'^\+?[0-9 ()-]{0,24}$').hasMatch(newValue.text)
          ? newValue
          : oldValue;
    }),
  ];

  static List<TextInputFormatter> text(int length) => [
    LengthLimitingTextInputFormatter(length),
  ];
}
