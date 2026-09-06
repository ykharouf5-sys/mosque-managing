import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/student/data/csv_grade_parser_service.dart';

void main() {
  test('rejects invalid component marks instead of silently dropping them', () {
    for (final component in ['oops', '-1', 'NaN', 'Infinity', '101']) {
      final result = CsvGradeParserService.parse(
        'exam_number,theoretical_mark,practical_mark,mark\n12345,$component,20,70',
      );
      expect(result.records, isEmpty);
      expect(result.issues.single.type, 'invalid_mark');
    }
  });
  test('parses the student result columns from an Arabic CSV file', () {
    const source =
        'الاسم,اسم الأب,الرقم الامتحاني,المادة,علامة النظري,علامة العملي\n'
        'ليان أحمد,أحمد,EX-17,الجراحة,42,38\n';

    final parsed = CsvGradeParserService.parse(source);

    expect(parsed.issues, isEmpty);
    expect(parsed.records, hasLength(1));
    expect(parsed.records.single.studentName, 'ليان أحمد');
    expect(parsed.records.single.fatherName, 'أحمد');
    expect(parsed.records.single.examNumber, 'EX-17');
    expect(parsed.records.single.theoreticalMark, 42);
    expect(parsed.records.single.practicalMark, 38);
    expect(parsed.records.single.mark, 80);
  });
}
