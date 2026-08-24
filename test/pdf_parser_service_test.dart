import 'package:studentry/student/data/pdf_parser_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('local PDF grade parsing', () {
    test('extracts exam number, student name, mark and status locally', () {
      final parsed = PdfParserService.parseGrades('''
12345
Ahmad Ali
87
Passed
23456 Sara Omar 42 Failed
''', examSession: 'first-2026');

      expect(parsed.records, hasLength(2));
      expect(parsed.records.first.examNumber, '12345');
      expect(parsed.records.first.studentName, 'Ahmad Ali');
      expect(parsed.records.first.mark, 87);
      expect(parsed.records.first.status, 'passed');
      expect(parsed.records.first.examSession, 'first-2026');
      expect(parsed.records.last.examNumber, '23456');
      expect(parsed.records.last.studentName, 'Sara Omar');
      expect(parsed.records.last.mark, 42);
      expect(parsed.records.last.status, 'failed');
    });

    test('rejects duplicate exam numbers and records the issue', () {
      final parsed = PdfParserService.parseGrades('''
12345 Ahmad 80 Passed
12345 Ahmad 81 Passed
''');

      expect(parsed.records, hasLength(1));
      expect(
        parsed.issues.any((issue) => issue.type == 'duplicate_exam'),
        isTrue,
      );
    });
  });
}
