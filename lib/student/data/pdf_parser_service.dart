import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'result_models.dart';

class PdfParserService {
  static String extractTextFromBytes(List<int> bytes) {
    if (bytes.isEmpty) return '';
    try {
      final doc = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(doc).extractText();
      doc.dispose();
      return text;
    } catch (e) {
      return '';
    }
  }

  static bool hasSufficientContent(String text) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.length >= 30;
  }

  static ParsedResult parseGrades(String rawText, {String? examSession}) {
    rawText = _normalizeDigits(rawText);
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final records = <ResultRecord>[];
    final issues = <ImportValidationIssue>[];
    final seenExamNumbers = <String>{};
    _PendingRecord? pending;

    debugPrint('=== PDF Parse Start: ${lines.length} lines ===');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Detect exam number (4-5 digits at start of line)
      final examMatch = RegExp(r'^(\d{4,5})(?!\d)').firstMatch(line);
      if (examMatch != null) {
        _finalizeRecord(pending, records, issues, seenExamNumbers, examSession);

        pending = _PendingRecord()
          ..examNumber = examMatch.group(1)!
          ..name = '';

        debugPrint('  🔢 رقم امتحان: ${pending.examNumber}');

        // Check if rest of same line has mark / status / name
        final rest = line.substring(examMatch.end).trim();
        if (rest.isNotEmpty) {
          final mark = _extractMark(rest);
          if (mark != null) {
            pending.mark = mark;
            debugPrint('  📝 علامة (من نفس السطر): $mark');
          }
          final status = _extractStatus(rest);
          if (status != null) {
            pending.status = status;
            debugPrint('  ✅ حالة (من نفس السطر): $status');
          }
          final nameFragment = _extractNameFragment(rest);
          if (nameFragment.isNotEmpty) pending._nameParts.add(nameFragment);
        }
        continue;
      }

      // No exam number on this line → part of current record
      if (pending == null) {
        debugPrint('  ⏭️ تخطي (لا يوجد سجل قيد الإنشاء): "${_truncate(line)}"');
        continue;
      }

      // Extract mark (if not already found)
      if (pending.mark == null) {
        final mark = _extractMark(line);
        if (mark != null) {
          pending.mark = mark;
          debugPrint('  📝 علامة: $mark');
          // Still check for status on same line
          final status = _extractStatus(line);
          if (status != null) {
            pending.status = status;
            debugPrint('  ✅ حالة: $status');
          }
          continue;
        }
      }

      // Extract status (if not already found, and we didn't just handle it)
      if (pending.status == null) {
        final status = _extractStatus(line);
        if (status != null) {
          pending.status = status;
          debugPrint('  ✅ حالة: $status');
          continue;
        }
      }

      // Duplicate mark line (pure number 0-100, already have mark)
      if (pending.mark != null) {
        final pureNum = double.tryParse(line);
        if (pureNum != null && pureNum >= 0 && pureNum <= 100) {
          debugPrint('  🔁 علامة مكررة: $line (تجاهل)');
          continue;
        }
      }

      // Nothing special → part of student name
      final cleaned = line
          .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.isNotEmpty) {
        pending._nameParts.add(cleaned);
        debugPrint('  👤 اسم: "$cleaned"');
      }
    }

    // Finalize last record
    _finalizeRecord(pending, records, issues, seenExamNumbers, examSession);

    debugPrint('=== PDF Parse End: ${records.length} سجل ===');
    return ParsedResult(records: records, issues: issues);
  }

  static void _finalizeRecord(
    _PendingRecord? pending,
    List<ResultRecord> records,
    List<ImportValidationIssue> issues,
    Set<String> seenExamNumbers,
    String? examSession,
  ) {
    if (pending == null) return;
    if (pending.examNumber.isEmpty) return;

    pending.name = pending._nameParts
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (pending.mark == null) {
      issues.add(
        ImportValidationIssue(
          type: 'missing_mark',
          examNumber: pending.examNumber,
          message: 'لا توجد علامة للرقم ${pending.examNumber}',
        ),
      );
      debugPrint('  ❌ تخطي (لا توجد علامة): رقم ${pending.examNumber}');
      return;
    }

    if (pending.status == null) {
      issues.add(
        ImportValidationIssue(
          type: 'missing_status',
          examNumber: pending.examNumber,
          message: 'لا توجد حالة للرقم ${pending.examNumber}',
        ),
      );
      debugPrint('  ❌ تخطي (لا توجد حالة): رقم ${pending.examNumber}');
      return;
    }

    if (seenExamNumbers.contains(pending.examNumber)) {
      issues.add(
        ImportValidationIssue(
          type: 'duplicate_exam',
          examNumber: pending.examNumber,
          message: 'رقم مكرر: ${pending.examNumber}',
        ),
      );
      debugPrint('  ❌ تخطي (مكرر): رقم ${pending.examNumber}');
      return;
    }
    seenExamNumbers.add(pending.examNumber);

    debugPrint(
      '  ✅ السجل: رقم=${pending.examNumber} | اسم=${pending.name} | علامة=${pending.mark} | حالة=${pending.status}',
    );

    records.add(
      ResultRecord(
        id: '${pending.examNumber}_${_simpleHash(pending.examNumber)}',
        examNumber: pending.examNumber,
        studentName: pending.name,
        subjectName: 'عام',
        mark: pending.mark!,
        total: 100,
        status: pending.status,
        examSession: examSession,
        uploadDate: DateTime.now(),
        sourcePdfId: '',
      ),
    );
  }

  static String _truncate(String s) =>
      s.length > 80 ? '${s.substring(0, 80)}...' : s;

  static String _extractNameFragment(String text) => text
      .replaceAll(
        RegExp(
          r'\b(?:Passed|Failed|Withheld)\b|ناجح|راسب|حجب|محروم',
          caseSensitive: false,
        ),
        ' ',
      )
      .replaceAll(RegExp(r'\b\d+(?:\.\d+)?\b'), ' ')
      .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Find the first valid mark (0-100) in a string.
  /// Skips "100" if a smaller mark exists to avoid picking up the total.
  static double? _extractMark(String text) {
    final matches = RegExp(r'(\d+\.?\d*)').allMatches(text);
    double? firstNon100;
    double? mark100;

    for (final m in matches) {
      final val = double.tryParse(m.group(1)!);
      if (val == null || val < 0 || val > 100) continue;
      if (val == 100) {
        mark100 ??= 100;
        continue;
      }
      firstNon100 ??= val;
    }

    return firstNon100 ?? mark100;
  }

  /// Detect status keyword, handling reversed RTL text from PDF extraction.
  /// Returns normalized English lowercase: 'passed', 'failed', 'withheld'.
  static String? _extractStatus(String text) {
    // Try original text first
    final result = matchStatus(text);
    if (result != null) {
      debugPrint('  Raw Status: "$text" → Normalized: "$result"');
      return result;
    }

    // Try reversed text (PDF extractors may reverse RTL character order)
    final reversed = String.fromCharCodes(text.runes.toList().reversed);
    if (reversed != text) {
      final revResult = matchStatus(reversed);
      if (revResult != null) {
        debugPrint(
          '  Raw Status (reversed): "$reversed" → Normalized: "$revResult"',
        );
        return revResult;
      }
    }

    return null;
  }

  static String? matchStatus(String text) {
    if (RegExp(
      r'ناجح|Passed|ن\s*ا\s*ج\s*ح|حجان',
      caseSensitive: false,
    ).hasMatch(text)) {
      return 'passed';
    }
    if (RegExp(
      r'راسب|Failed|ر\s*ا\s*س\s*ب|بسار',
      caseSensitive: false,
    ).hasMatch(text)) {
      return 'failed';
    }
    if (RegExp(
      r'حجب|Withheld|ح\s*ج\s*ب|محروم|م\s*ح\s*ر\s*و\s*م|بحج|مورحم',
      caseSensitive: false,
    ).hasMatch(text)) {
      return 'withheld';
    }
    return null;
  }

  static String _simpleHash(String input) {
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = 31 * hash + input.codeUnitAt(i);
    }
    return (hash & 0xFFFFFFFF).toRadixString(36).padLeft(6, '0');
  }

  static String _normalizeDigits(String text) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const western = '0123456789';
    final buf = StringBuffer();
    for (final c in text.runes) {
      final idx = arabic.indexOf(String.fromCharCode(c));
      if (idx >= 0) {
        buf.write(western[idx]);
      } else {
        buf.writeCharCode(c);
      }
    }
    return buf.toString();
  }
}

class _PendingRecord {
  String examNumber = '';
  final _nameParts = <String>[];
  double? mark;
  String? status;

  String get name =>
      _nameParts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  set name(String v) {
    _nameParts.clear();
    _nameParts.add(v);
  }
}

class ParsedResult {
  final List<ResultRecord> records;
  final List<ImportValidationIssue> issues;

  ParsedResult({required this.records, required this.issues});

  bool get hasIssues => issues.isNotEmpty;
  int get validCount => records.length;
  int get issueCount => issues.length;
}
