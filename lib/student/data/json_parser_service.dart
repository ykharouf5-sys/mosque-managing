import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'result_models.dart';
import 'pdf_parser_service.dart';

class JsonParserService {
  static ParsedResult parseJson(String jsonString, {String? examSession}) {
    List<dynamic> items;
    try {
      items = jsonDecode(jsonString) as List<dynamic>;
    } catch (e) {
      return ParsedResult(
        records: [],
        issues: [
          ImportValidationIssue(
            type: 'invalid_json',
            message: 'الملف ليس JSON صالح: $e',
          ),
        ],
      );
    }

    final records = <ResultRecord>[];
    final issues = <ImportValidationIssue>[];
    final seenExamNumbers = <String>{};

    debugPrint('=== JSON Parse Start: ${items.length} items ===');

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is! Map) {
        issues.add(
          ImportValidationIssue(
            type: 'invalid_row',
            rowIndex: i,
            message: 'الصف $i ليس كائن JSON صالح',
          ),
        );
        continue;
      }

      final map = item as Map<String, dynamic>;

      // Extract fields (Arabic or English keys)
      final examNumber = _pickString(map, [
        'examNumber',
        'exam_number',
        'رقم امتحاني',
        'رقم',
        'exam_no',
      ]);
      final studentName = _pickString(map, [
        'studentName',
        'student_name',
        'اسم الطالب',
        'اسم',
        'name',
        'الاسم',
      ]);
      final markRaw = _pickString(map, [
        'mark',
        'علامة',
        'grade',
        'degree',
        'العلامة',
        'الدرجة',
      ]);
      final statusRaw = _pickString(map, [
        'status',
        'حالة',
        'result',
        'النتيجة',
        'الحالة',
      ]);
      final subjectName = _pickString(map, [
        'subjectName',
        'subject',
        'المادة',
        'subject_name',
        'مادة',
      ]);

      if (examNumber == null || examNumber.isEmpty) {
        issues.add(
          ImportValidationIssue(
            type: 'missing_exam',
            rowIndex: i,
            message: 'الصف ${i + 1}: رقم امتحاني مطلوب',
          ),
        );
        continue;
      }

      if (markRaw == null || markRaw.isEmpty) {
        issues.add(
          ImportValidationIssue(
            type: 'missing_mark',
            examNumber: examNumber,
            rowIndex: i,
            message: 'الصف ${i + 1} (رقم $examNumber): علامة مطلوبة',
          ),
        );
        continue;
      }

      final mark = double.tryParse(markRaw);
      if (mark == null || mark < 0 || mark > 100) {
        issues.add(
          ImportValidationIssue(
            type: 'invalid_mark',
            examNumber: examNumber,
            rowIndex: i,
            message:
                'الصف ${i + 1} (رقم $examNumber): علامة غير صالحة: "$markRaw"',
          ),
        );
        continue;
      }

      if (seenExamNumbers.contains(examNumber)) {
        issues.add(
          ImportValidationIssue(
            type: 'duplicate_exam',
            examNumber: examNumber,
            rowIndex: i,
            message: 'الصف ${i + 1}: رقم مكرر: $examNumber',
          ),
        );
        continue;
      }
      seenExamNumbers.add(examNumber);

      final status = _normalizeStatus(statusRaw ?? '');
      final subject = (subjectName != null && subjectName.isNotEmpty)
          ? subjectName
          : 'عام';

      debugPrint(
        '  ✅ رقم=$examNumber | اسم=${studentName ?? ''} | مادة=$subject | علامة=$mark | حالة=$status',
      );

      records.add(
        ResultRecord(
          id: '${examNumber}_${_simpleHash(examNumber)}',
          examNumber: examNumber,
          studentName: studentName ?? '',
          subjectName: subject,
          mark: mark,
          total: 100,
          status: status,
          examSession: examSession,
          uploadDate: DateTime.now(),
          sourcePdfId: '',
        ),
      );
    }

    debugPrint('=== JSON Parse End: ${records.length} سجل ===');
    return ParsedResult(records: records, issues: issues);
  }

  static String? _pickString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final val = map[key];
      if (val != null) {
        if (val is String && val.trim().isNotEmpty) return val.trim();
        if (val is num) return val.toString();
      }
    }
    return null;
  }

  static String? _normalizeStatus(String raw) {
    if (raw.isEmpty) return null;
    final s = raw.trim();
    // Use the same status matcher from PdfParserService
    return PdfParserService.matchStatus(s);
  }

  static String _simpleHash(String input) {
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = 31 * hash + input.codeUnitAt(i);
    }
    return (hash & 0xFFFFFFFF).toRadixString(36).padLeft(6, '0');
  }
}
