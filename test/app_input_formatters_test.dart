import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/utils/app_input_formatters.dart';

TextEditingValue edit(
  List<TextInputFormatter> formatters,
  String input, {
  String previous = '',
}) {
  final oldValue = TextEditingValue(
    text: previous,
    selection: TextSelection.collapsed(offset: previous.length),
  );
  return formatters.fold(
    TextEditingValue(
      text: input,
      selection: TextSelection.collapsed(offset: input.length),
    ),
    (value, formatter) => formatter.formatEditUpdate(oldValue, value),
  );
}

void main() {
  test(
    'numeric paste normalizes Arabic and Persian digits and limits length',
    () {
      expect(edit(AppInputFormatters.integer(digits: 3), '١٢٣٤٥٦').text, '123');
      expect(edit(AppInputFormatters.integer(digits: 3), '۱۲۳').text, '123');
      expect(edit(AppInputFormatters.integer(digits: 3), '12abc').text, '12');
      expect(edit(AppInputFormatters.integer(digits: 3), '').text, isEmpty);
    },
  );
  test(
    'academic upper limits match the current backend and allow clearing',
    () {
      final count = AppInputFormatters.integer(digits: 3, max: 500);
      expect(edit(count, '500').text, '500');
      expect(edit(count, '501', previous: '50').text, '50');
      expect(edit(count, '', previous: '50').text, isEmpty);
      expect(
        edit(AppInputFormatters.integer(digits: 2, max: 40), '41').text,
        '',
      );
      expect(
        edit(AppInputFormatters.integer(digits: 2, max: 80), '80').text,
        '80',
      );
    },
  );
  test(
    'amounts allow two decimal places, Arabic separator and blank values',
    () {
      final amount = AppInputFormatters.decimal();
      expect(edit(amount, '١٢٣٫٤٥').text, '123.45');
      expect(edit(amount, '12.345', previous: '12.34').text, '12.34');
      expect(edit(amount, '-12', previous: '').text, '');
      expect(edit(amount, '12345678901').text, '');
      expect(edit(amount, '').text, '');
    },
  );
  test(
    'phone input preserves international formatting but rejects letters',
    () {
      expect(
        edit(AppInputFormatters.phone, '+٩٦٣ (٩٣٣) ١٢٣-٤٥٦').text,
        '+963 (933) 123-456',
      );
      expect(
        edit(AppInputFormatters.phone, 'abc', previous: '+963').text,
        '+963',
      );
      expect(edit(AppInputFormatters.phone, '9' * 30).text, '');
      expect(edit(AppInputFormatters.phone, '').text, '');
    },
  );
  test('text limits preserve grapheme clusters instead of cutting emoji', () {
    expect(
      edit(AppInputFormatters.text(2), 'أ👨‍👩‍👧‍👦ب').text,
      'أ👨‍👩‍👧‍👦',
    );
  });
}
