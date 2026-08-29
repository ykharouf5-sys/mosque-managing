import 'package:studentry/student/data/result_models.dart';
import 'package:studentry/student/data/academic_result_api_service.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/shared/utils/search_debouncer.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class StudentGradesScreen extends ConsumerStatefulWidget {
  const StudentGradesScreen({super.key});

  @override
  ConsumerState<StudentGradesScreen> createState() =>
      _StudentGradesScreenState();
}

class _StudentGradesScreenState extends ConsumerState<StudentGradesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final SearchDebouncer _searchDebouncer = SearchDebouncer();
  List<ResultRecord> _results = [];
  bool _loading = false;
  bool _searched = false;
  bool _exporting = false;
  bool _loadingSamples = false;
  final List<String> _storedExamNumbers = [];
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _tryAutoLoad();
    _fetchSampleExamNumbers();
  }

  @override
  void dispose() {
    _searchGeneration++;
    _searchDebouncer.dispose();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _tryAutoLoad() async {
    final examNumber = AuthService().examNumber?.trim();
    if (examNumber == null || examNumber.isEmpty) return;
    _searchCtrl.text = examNumber;
    await _search();
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    final generation = ++_searchGeneration;

    setState(() {
      _loading = true;
      _searched = true;
    });

    try {
      final results = await const AcademicResultApiService().results(
        examNumber: query,
      );
      if (mounted && generation == _searchGeneration) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
      if (results.isEmpty && mounted && generation == _searchGeneration) {
        _fetchSampleExamNumbers();
      }
    } catch (e) {
      if (mounted && generation == _searchGeneration) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchGeneration++;
    setState(() {});
    if (value.trim().isEmpty) {
      _searchDebouncer.cancel();
      setState(() {
        _results = [];
        _searched = false;
        _loading = false;
      });
      return;
    }
    _searchDebouncer.schedule(_search);
  }

  void _submitSearch() => _searchDebouncer.runNow(_search);

  Future<void> _fetchSampleExamNumbers() async {
    final examNumber = AuthService().examNumber?.trim();
    if (!mounted) return;
    setState(() {
      _storedExamNumbers
        ..clear()
        ..addAll(
          examNumber == null || examNumber.isEmpty ? const [] : [examNumber],
        );
      _loadingSamples = false;
    });
  }

  double get _average {
    if (_results.isEmpty) return 0;
    return _results.fold<double>(0, (s, r) => s + r.mark) / _results.length;
  }

  Color _gradeColor(double pct) {
    if (pct >= 85) return AppColors.success;
    if (pct >= 70) return AppColors.primary;
    if (pct >= 50) return AppColors.pending;
    return Colors.red;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'passed':
        return AppColors.success;
      case 'failed':
        return AppColors.danger;
      case 'withheld':
        return AppColors.pending;
      default:
        return AppColors.textGray;
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final fontData = await rootBundle.load(
        'assets/fonts/NotoNaskhArabic-Regular.ttf',
      );
      final fontBoldData = await rootBundle.load(
        'assets/fonts/NotoNaskhArabic-Bold.ttf',
      );
      final font = pw.Font.ttf(fontData);
      final fontBold = pw.Font.ttf(fontBoldData);

      final passed = _results.where((r) => r.status == 'passed').length;
      final failed = _results.where((r) => r.status == 'failed').length;

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          header: (context) => pw.Center(
            child: pw.Text(
              'كشف العلامات',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 22,
                color: PdfColors.blue800,
              ),
            ),
          ),
          footer: (context) => pw.Center(
            child: pw.Text(
              'تم التصدير من تطبيق Studentry',
              style: pw.TextStyle(
                font: font,
                fontSize: 9,
                color: PdfColors.grey500,
              ),
            ),
          ),
          build: (context) => [
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'الرقم الامتحاني: ${_searchCtrl.text}',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 12,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.Text(
                    'المعدل: ${_average.toStringAsFixed(1)}',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 16,
                      color: PdfColors.blue800,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Text(
                  'ناجح: $passed',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 11,
                    color: PdfColors.green700,
                  ),
                ),
                pw.Text(
                  'راسب: $failed',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 11,
                    color: PdfColors.red700,
                  ),
                ),
                pw.Text(
                  'عدد المواد: ${_results.length}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 11,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.TableHelper.fromTextArray(
              headerAlignment: pw.Alignment.center,
              cellAlignment: pw.Alignment.center,
              headerStyle: pw.TextStyle(
                font: fontBold,
                fontSize: 11,
                color: PdfColors.white,
              ),
              cellStyle: pw.TextStyle(font: font, fontSize: 11),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue700,
              ),
              border: const pw.TableBorder(
                horizontalInside: pw.BorderSide(color: PdfColors.grey300),
                verticalInside: pw.BorderSide(color: PdfColors.grey300),
                bottom: pw.BorderSide(color: PdfColors.grey300),
              ),
              headers: ['#', 'المادة', 'العلامة', 'الحالة'],
              data: List.generate(_results.length, (i) {
                final r = _results[i];
                final pct = r.total > 0 ? r.mark / r.total * 100 : 0.0;
                final rating = pct >= 85
                    ? 'ممتاز'
                    : pct >= 70
                    ? 'جيد جداً'
                    : pct >= 50
                    ? 'مقبول'
                    : 'ضعيف';
                return [
                  '${i + 1}',
                  r.subjectName,
                  '${r.mark.toStringAsFixed(0)}/${r.total.toStringAsFixed(0)} ($rating)',
                  r.statusLabel,
                ];
              }),
            ),
            pw.SizedBox(height: 24),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 16,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Text(
                'عدد المواد: ${_results.length} • المعدل: ${_average.toStringAsFixed(1)}',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'علاماتي.pdf',
        subject: 'علاماتي',
        body: 'كشف العلامات - ${_searchCtrl.text}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل تصدير PDF: $e')));
      }
    } finally {
      setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'علاماتي',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: AppColors.surface,
          elevation: 0,
          actions: [
            if (_results.isNotEmpty)
              IconButton(
                icon: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.picture_as_pdf_outlined,
                        color: AppColors.primary,
                      ),
                tooltip: 'تصدير PDF',
                onPressed: _exporting ? null : _exportPdf,
              ),
          ],
        ),
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _focusNode,
        textDirection: TextDirection.ltr,
        textInputAction: TextInputAction.search,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: 'أدخل رقمك الامتحاني',
          hintTextDirection: TextDirection.rtl,
          prefixIcon: Icon(
            Icons.search,
            color: AppColors.textGray,
            size: 20.sp,
          ),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18.sp,
                    color: AppColors.textGray,
                  ),
                  onPressed: () {
                    _searchCtrl.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 14.h,
          ),
        ),
        style: TextStyle(fontSize: 14.sp),
        onSubmitted: (_) => _submitSearch(),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_searched) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(16.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 40.h),
            Icon(
              Icons.score_outlined,
              size: 80.sp,
              color: AppColors.textGray.withValues(alpha: 0.3),
            ),
            SizedBox(height: 16.h),
            Text(
              'أدخل رقمك الامتحاني',
              style: TextStyle(fontSize: 16.sp, color: AppColors.textGray),
            ),
            SizedBox(height: 8.h),
            Text(
              'للعرض جميع نتائجك',
              style: TextStyle(fontSize: 13.sp, color: AppColors.textGray),
            ),
            if (_storedExamNumbers.isNotEmpty) ...[
              SizedBox(height: 30.h),
              _buildStoredNumbersSection(),
            ] else if (_loadingSamples) ...[
              SizedBox(height: 30.h),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(16.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 40.h),
            Icon(
              Icons.search_off_rounded,
              size: 80.sp,
              color: AppColors.textGray.withValues(alpha: 0.3),
            ),
            SizedBox(height: 16.h),
            Text(
              'لا توجد نتائج',
              style: TextStyle(fontSize: 16.sp, color: AppColors.textGray),
            ),
            SizedBox(height: 8.h),
            Text(
              'الرقم "${_searchCtrl.text}" غير موجود',
              style: TextStyle(fontSize: 13.sp, color: AppColors.textGray),
            ),
            if (_storedExamNumbers.isNotEmpty) ...[
              SizedBox(height: 20.h),
              _buildStoredNumbersSection(),
            ],
          ],
        ),
      );
    }

    final passed = _results.where((r) => r.status == 'passed').length;
    final failed = _results.where((r) => r.status == 'failed').length;

    return Column(
      children: [
        _buildSummaryCard(passed, failed),
        SizedBox(height: 8.h),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: _results.length,
            itemBuilder: (_, i) => _buildResultCard(_results[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildStoredNumbersSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.storage_rounded,
                size: 14.sp,
                color: AppColors.pending,
              ),
              SizedBox(width: 6.w),
              Text(
                'الأرقام الامتحانية المخزنة',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const Spacer(),
              Text(
                '${_storedExamNumbers.length}',
                style: TextStyle(fontSize: 11.sp, color: AppColors.textGray),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          if (_storedExamNumbers.isEmpty)
            Text(
              'لا توجد أرقام مخزنة',
              style: TextStyle(fontSize: 11.sp, color: AppColors.textGray),
            )
          else
            Wrap(
              spacing: 6.w,
              runSpacing: 4.h,
              children: _storedExamNumbers
                  .map(
                    (n) => GestureDetector(
                      onTap: () {
                        _searchCtrl.text = n;
                        _search();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          n,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(int passed, int failed) {
    return Container(
      margin: EdgeInsets.all(16.r),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF1565C0)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المعدل',
                  style: TextStyle(fontSize: 13.sp, color: Colors.white70),
                ),
                SizedBox(height: 4.h),
                Text(
                  _average.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '$passed ناجح • $failed راسب',
                  style: TextStyle(fontSize: 11.sp, color: Colors.white60),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_results.length} مادة',
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(ResultRecord record) {
    final pct = record.total > 0 ? (record.mark / record.total * 100) : 0.0;
    final color = _gradeColor(pct);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 50.h,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.subjectName,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          if (record.examSession != null &&
                              record.examSession!.isNotEmpty)
                            Text(
                              record.examSession!,
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: AppColors.textGray,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (record.status != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(
                            record.status!,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          record.statusLabel,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: _statusColor(record.status!),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 4.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor: AppColors.divider.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6.h,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${record.mark.toStringAsFixed(0)}/${record.total.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
