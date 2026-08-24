import 'dart:io';
import 'package:studentry/student/data/grade_service.dart';
import 'package:studentry/student/data/subject_models.dart';
import 'package:studentry/student/data/academic_store.dart';

import 'package:studentry/utils/variable_colors.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

const Color _kWarning = Color(0xFFFF9800);

class AdminGradesScreen extends ConsumerStatefulWidget {
  const AdminGradesScreen({super.key});

  @override
  ConsumerState<AdminGradesScreen> createState() => _AdminGradesScreenState();
}

class _AdminGradesScreenState extends ConsumerState<AdminGradesScreen> {
  final AcademicStore _academic = AcademicStore.instance;
  Subject? _selectedSubject;
  String? _pdfName;
  String? _rawText;
  bool _loading = false;
  bool _saving = false;
  bool _showManualInput = false;
  final TextEditingController _manualCtrl = TextEditingController();

  final List<Map<String, dynamic>> _parsedGrades = [];
  final Set<int> _selectedRows = {};

  List<Subject> get _subjects => _academic.subjects;

  @override
  void initState() {
    super.initState();
    _academic.addListener(_onAcademicChanged);
    _academic.load();
  }

  @override
  void dispose() {
    _academic.removeListener(_onAcademicChanged);
    _manualCtrl.dispose();
    super.dispose();
  }

  void _onAcademicChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pickSubject() async {
    final subject = await showDialog<Subject>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اختر المادة'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _subjects.length,
              itemBuilder: (_, i) {
                final s = _subjects[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: parseColor(s.color).withValues(alpha: 0.1),
                    child: Text(
                      s.code.substring(0, 2),
                      style: TextStyle(
                        color: parseColor(s.color),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(s.name),
                  subtitle: Text('${s.code} • السنة ${s.academicYear}'),
                  onTap: () => Navigator.pop(ctx, s),
                );
              },
            ),
          ),
        ),
      ),
    );
    if (subject != null) setState(() => _selectedSubject = subject);
  }

  Future<void> _pickAndParsePdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.path == null) return;

      setState(() {
        _pdfName = file.name;
        _loading = true;
      });

      final bytes = await File(file.path!).readAsBytes();
      if (bytes.isEmpty) {
        _showError('الملف فارغ');
        return;
      }
      final doc = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(doc).extractText();
      doc.dispose();
      _rawText = text;
      _parseGrades(text);
    } catch (_) {
      _showError(
        'فشل قراءة الملف: تأكد من أن الملف PDF نصي وليس ممسوحاً ضوئياً',
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  static String _normalizeDigits(String text) {
    // Arabic-Indic digits (٠-٩) → Western digits (0-9)
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

  void _parseGrades(String text) {
    // Normalise Arabic-Indic digits first
    text = _normalizeDigits(text);

    final lines = text.split('\n');
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};

    // Skip header-like lines
    bool isHeader(String line) {
      return RegExp(
        r'صفحة|Page|page|رقم|تاريخ|Name|name|Student|student|الطالب|الدرجة|Degree|degree|Grade|grade|علامة|اسم|المادة|المعدل|المجموع|العام|الجامعي|الكلية|القسم|الشعبة|الرقم|التسلسل|المبحث|النظري|العملي|النهائي|النتيجة|ناجح|راسب|مقبول|جيد|ممتاز',
        caseSensitive: false,
      ).hasMatch(line);
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (isHeader(trimmed)) continue;

      // Skip lines with only alphabetic/header content
      if (RegExp(r'^[أ-ي\s\-_/\\|]{3,}$').hasMatch(trimmed)) continue;

      // Extract all numbers from the line
      final allNumbers = RegExp(
        r'(\d+\.?\d*)',
      ).allMatches(trimmed).map((m) => m.group(1)!).toList();
      if (allNumbers.length < 2) continue;

      // Last number is likely the grade
      final gradeStr = allNumbers.last;
      final grade = double.tryParse(gradeStr) ?? -1;
      if (grade < 0 || grade > 100) continue;

      // Try each preceding number as potential student ID
      String? id;
      for (final num in allNumbers.sublist(0, allNumbers.length - 1)) {
        final candidate = num.replaceAll(RegExp(r'\.0*$'), '');
        if (candidate.length >= 3 && !seen.contains(candidate)) {
          id = candidate;
          break;
        }
      }

      if (id != null) {
        seen.add(id);
        results.add({'id': id, 'grade': grade, 'raw': trimmed});
      }
    }

    setState(() {
      _parsedGrades.clear();
      _selectedRows.clear();
      _parsedGrades.addAll(results);
    });

    if (results.isEmpty) {
      _showError(
        'لم نتمكن من استخراج علامات من الملف. جرب تفتح الملف وتتأكد من وجود أرقام الطلاب والعلامات.',
      );
    }
  }

  Future<void> _saveGrades() async {
    if (_selectedSubject == null) return;
    if (_parsedGrades.isEmpty) {
      _showError('لا توجد علامات للحفظ');
      return;
    }

    final items = _selectedRows.isNotEmpty
        ? _selectedRows.map((i) => _parsedGrades[i]).toList()
        : _parsedGrades;

    setState(() => _saving = true);
    try {
      final gradesMap = <String, double>{};
      for (final item in items) {
        gradesMap[item['id'] as String] = (item['grade'] as num).toDouble();
      }
      await StudentGradesService.saveSubjectGrades(
        subjectId: _selectedSubject!.id,
        subjectName: _selectedSubject!.name,
        grades: gradesMap,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ العلامات بنجاح')));
        setState(() {
          _selectedSubject = null;
          _pdfName = null;
          _parsedGrades.clear();
          _selectedRows.clear();
        });
      }
    } catch (e) {
      _showError('فشل الحفظ: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showRawText(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('النص المستخرج من PDF'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                _rawText ?? '',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'رفع العلامات',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection(
                      'المادة',
                      _selectedSubject?.name ?? 'اختر مادة',
                      Icons.menu_book_outlined,
                      _selectedSubject != null
                          ? parseColor(_selectedSubject!.color)
                          : AppColors.primary,
                      () => _pickSubject(),
                    ),
                    SizedBox(height: 12.h),
                    _buildSection(
                      'ملف PDF',
                      _pdfName ?? 'اختر ملف العلامات',
                      Icons.picture_as_pdf_outlined,
                      const Color(0xFFE53935),
                      () => _pickAndParsePdf(),
                    ),
                    if (_loading) ...[
                      SizedBox(height: 20.h),
                      const Center(child: CircularProgressIndicator()),
                    ],
                    if (!_loading &&
                        _pdfName != null &&
                        _parsedGrades.isEmpty &&
                        _rawText != null) ...[
                      SizedBox(height: 12.h),
                      Container(
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: _kWarning.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _kWarning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16.sp,
                                  color: _kWarning,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  'لم يتم استخراج علامات',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                    color: _kWarning,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'قد يكون تنسيق الملف مختلف. يمكنك عرض النص المستخرج للمساعدة:',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.textGray,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: Icon(
                                  Icons.text_snippet_outlined,
                                  size: 16.sp,
                                ),
                                label: const Text('عرض النص المستخرج'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: BorderSide(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onPressed: () => _showRawText(context),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: Icon(Icons.edit_outlined, size: 16.sp),
                                label: const Text('إدخال العلامات يدوياً'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _kWarning,
                                  side: BorderSide(
                                    color: _kWarning.withValues(alpha: 0.5),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onPressed: () =>
                                    setState(() => _showManualInput = true),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_showManualInput) ...[
                      SizedBox(height: 12.h),
                      Container(
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.edit_note,
                                  size: 16.sp,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  'إدخال يدوي',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'أدخل كل طالب في سطر: الرقم الجامعي ثم العلامة (مثال: 2021001 85)',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.textGray,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            TextField(
                              controller: _manualCtrl,
                              maxLines: 8,
                              textDirection: TextDirection.rtl,
                              decoration: InputDecoration(
                                hintText: '2021001 85\n2021002 90\n2021003 75',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: EdgeInsets.all(12.r),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.done_outline, size: 18),
                                label: const Text('تحليل النص'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                onPressed: () {
                                  _parseGrades(_manualCtrl.text);
                                  setState(() => _showManualInput = false);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_parsedGrades.isNotEmpty) ...[
                      SizedBox(height: 20.h),
                      Row(
                        children: [
                          Icon(
                            Icons.table_chart_outlined,
                            size: 18.sp,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'العلامات المستخرجة (${_parsedGrades.length})',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const Spacer(),
                          if (_parsedGrades.isNotEmpty)
                            TextButton.icon(
                              icon: Icon(Icons.select_all, size: 16.sp),
                              label: Text(
                                _selectedRows.length == _parsedGrades.length
                                    ? 'إلغاء الكل'
                                    : 'تحديد الكل',
                                style: TextStyle(fontSize: 12.sp),
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_selectedRows.length ==
                                      _parsedGrades.length) {
                                    _selectedRows.clear();
                                  } else {
                                    _selectedRows.addAll(
                                      List.generate(
                                        _parsedGrades.length,
                                        (i) => i,
                                      ),
                                    );
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.divider.withValues(alpha: 0.5),
                          ),
                        ),
                        child: _parsedGrades.length > 20
                            ? SizedBox(
                                height: 400.h,
                                child: _buildGradesTable(),
                              )
                            : _buildGradesTable(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_parsedGrades.isNotEmpty)
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton.icon(
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'جاري الحفظ...' : 'حفظ العلامات'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: _saving ? null : _saveGrades,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradesTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          AppColors.primary.withValues(alpha: 0.05),
        ),
        columns: [
          DataColumn(
            label: SizedBox(
              width: 40.w,
              child: Text(
                '#',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp),
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'الطالب',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp),
            ),
          ),
          DataColumn(
            label: Text(
              'العلامة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp),
            ),
            numeric: true,
          ),
        ],
        rows: List.generate(_parsedGrades.length, (i) {
          final item = _parsedGrades[i];
          final selected = _selectedRows.contains(i);
          return DataRow(
            selected: selected,
            onSelectChanged: (v) {
              setState(() {
                if (v == true) {
                  _selectedRows.add(i);
                } else {
                  _selectedRows.remove(i);
                }
              });
            },
            cells: [
              DataCell(
                SizedBox(
                  width: 40.w,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textGray,
                    ),
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 150.w,
                  child: Text(
                    item['id'] as String,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(
                Text(
                  (item['grade'] as num).toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSection(
    String label,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textGray,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left, color: AppColors.textGray, size: 20.sp),
          ],
        ),
      ),
    );
  }
}
