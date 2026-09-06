import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/student/data/json_parser_service.dart';

void main() {
  test('imports Arabic identity and theoretical/practical columns', () {
    final parsed = JsonParserService.parseJson(r'''
      [{
        "الرقم الامتحاني":"DU-101",
        "الاسم":"أحمد",
        "اسم الأب":"محمد",
        "المادة":"الجراحة",
        "علامة النظري":45,
        "علامة العملي":40
      }]
    ''');

    expect(parsed.issues, isEmpty);
    expect(parsed.records, hasLength(1));
    expect(parsed.records.single.fatherName, 'محمد');
    expect(parsed.records.single.theoreticalMark, 45);
    expect(parsed.records.single.practicalMark, 40);
    expect(parsed.records.single.mark, 85);
  });
}
