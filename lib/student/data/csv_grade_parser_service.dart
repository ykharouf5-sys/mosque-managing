import 'dart:convert';

import 'json_parser_service.dart';
import 'pdf_parser_service.dart';
import 'result_models.dart';

class CsvGradeParserService {
  static ParsedResult parse(String source, {String? examSession}) {
    final lines = const LineSplitter()
        .convert(source.replaceFirst('\ufeff', ''))
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    if (lines.length < 2) {
      return ParsedResult(
        records: const [],
        issues: [
          ImportValidationIssue(
            type: 'invalid_csv',
            message: 'ملف CSV لا يحتوي على صفوف نتائج',
          ),
        ],
      );
    }

    final delimiter = _delimiterFor(lines.first);
    final headers = _splitLine(lines.first, delimiter)
        .map((value) => value.trim())
        .toList(growable: false);
    final rows = <Map<String, dynamic>>[];
    for (final line in lines.skip(1)) {
      final values = _splitLine(line, delimiter);
      rows.add({
        for (var index = 0; index < headers.length; index++)
          headers[index]: index < values.length ? values[index].trim() : '',
      });
    }
    return JsonParserService.parseJson(
      jsonEncode(rows),
      examSession: examSession,
    );
  }

  static String _delimiterFor(String header) {
    final candidates = [',', ';', '\t'];
    candidates.sort(
      (a, b) => _countOutsideQuotes(header, b)
          .compareTo(_countOutsideQuotes(header, a)),
    );
    return candidates.first;
  }

  static int _countOutsideQuotes(String value, String delimiter) {
    var quoted = false;
    var count = 0;
    for (var index = 0; index < value.length; index++) {
      if (value[index] == '"') quoted = !quoted;
      if (!quoted && value[index] == delimiter) count++;
    }
    return count;
  }

  static List<String> _splitLine(String line, String delimiter) {
    final values = <String>[];
    final current = StringBuffer();
    var quoted = false;
    for (var index = 0; index < line.length; index++) {
      final char = line[index];
      if (char == '"') {
        if (quoted && index + 1 < line.length && line[index + 1] == '"') {
          current.write('"');
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (!quoted && char == delimiter) {
        values.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    values.add(current.toString());
    return values;
  }
}
