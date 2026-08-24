import 'package:studentry/student/data/result_models.dart';
import 'package:studentry/student/data/academic_result_api_service.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ResultHistoryScreen extends ConsumerStatefulWidget {
  final String? initialExamNumber;
  const ResultHistoryScreen({super.key, this.initialExamNumber});

  @override
  ConsumerState<ResultHistoryScreen> createState() =>
      _ResultHistoryScreenState();
}

class _ResultHistoryScreenState extends ConsumerState<ResultHistoryScreen> {
  final TextEditingController _examCtrl = TextEditingController();
  String? _currentExamNumber;
  List<ResultRecord> _allResults = [];
  String? _selectedSubject;
  List<String> _availableSubjects = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialExamNumber != null &&
        widget.initialExamNumber!.isNotEmpty) {
      _examCtrl.text = widget.initialExamNumber!;
      _currentExamNumber = widget.initialExamNumber;
      _loadHistory();
    }
  }

  @override
  void dispose() {
    _examCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final examNumber = _examCtrl.text.trim();
    if (examNumber.isEmpty) return;

    setState(() {
      _loading = true;
      _currentExamNumber = examNumber;
    });

    try {
      final results = await const AcademicResultApiService().results(
        examNumber: examNumber,
      );
      final subjects =
          results.map((result) => result.subjectName).toSet().toList()..sort();

      if (mounted) {
        setState(() {
          _availableSubjects = subjects;
          _allResults = results;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
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
            'سجل النتائج',
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
            _buildSearchSection(),
            if (_currentExamNumber != null) ...[
              if (_availableSubjects.isNotEmpty) _buildSubjectFilter(),
              SizedBox(height: 4.h),
            ],
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      margin: EdgeInsets.all(16.r),
      child: Row(
        children: [
          Expanded(
            child: Container(
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
                controller: _examCtrl,
                textDirection: TextDirection.ltr,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'الرقم الامتحاني',
                  hintTextDirection: TextDirection.rtl,
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.textGray,
                    size: 20.sp,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 14.h,
                  ),
                ),
                style: TextStyle(fontSize: 14.sp),
                onSubmitted: (_) => _loadHistory(),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.search_rounded, color: Colors.white),
              onPressed: _loading ? null : _loadHistory,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectFilter() {
    return Container(
      height: 44.h,
      margin: EdgeInsets.only(right: 16.w, left: 16.w, bottom: 8.h),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('الكل', _selectedSubject == null),
          ..._availableSubjects.map(
            (s) => _buildFilterChip(s, _selectedSubject == s),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSubject = isSelected ? null : label;
        });
        _loadHistory();
      },
      child: Container(
        margin: EdgeInsets.only(left: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label == 'الكل' ? 'كل المواد' : label,
          style: TextStyle(
            fontSize: 12.sp,
            color: isSelected ? Colors.white : AppColors.textDark,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentExamNumber == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
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
              'لعرض جميع نتائجك السابقة',
              style: TextStyle(fontSize: 13.sp, color: AppColors.textGray),
            ),
          ],
        ),
      );
    }

    if (_allResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 80.sp,
              color: AppColors.textGray.withValues(alpha: 0.3),
            ),
            SizedBox(height: 16.h),
            Text(
              'لا توجد نتائج',
              style: TextStyle(fontSize: 16.sp, color: AppColors.textGray),
            ),
          ],
        ),
      );
    }

    // Group results by exam session
    final grouped = <String, List<ResultRecord>>{};
    for (final r in _allResults) {
      final session = r.examSession ?? 'بدون دورة';
      grouped.putIfAbsent(session, () => []).add(r);
    }

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      children: [
        // Overall stats
        _buildOverallStats(),
        SizedBox(height: 16.h),
        // Results grouped by session
        ...grouped.entries.map(
          (entry) => _buildSessionGroup(entry.key, entry.value),
        ),
        SizedBox(height: 24.h),
      ],
    );
  }

  Widget _buildOverallStats() {
    final total = _allResults.length;
    final avg = total > 0
        ? _allResults.fold<double>(0, (s, r) => s + r.mark) / total
        : 0.0;
    final max = total > 0
        ? _allResults.map((r) => r.mark).reduce((a, b) => a > b ? a : b)
        : 0.0;
    final min = total > 0
        ? _allResults.map((r) => r.mark).reduce((a, b) => a < b ? a : b)
        : 0.0;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الاحصائيات العامة',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              _buildStat('المعدل', avg.toStringAsFixed(1), AppColors.primary),
              _buildStat(
                'أعلى علامة',
                max.toStringAsFixed(0),
                AppColors.success,
              ),
              _buildStat(
                'أدنى علامة',
                min.toStringAsFixed(0),
                AppColors.danger,
              ),
              _buildStat('عدد المواد', '$total', AppColors.textGray),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(fontSize: 10.sp, color: AppColors.textGray),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionGroup(String session, List<ResultRecord> results) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14.sp,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8.w),
                Text(
                  session,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${results.length} نتيجة',
                  style: TextStyle(fontSize: 11.sp, color: AppColors.textGray),
                ),
              ],
            ),
          ),
          ...results.map((r) => _buildHistoryRow(r)),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(ResultRecord record) {
    final pct = record.total > 0 ? (record.mark / record.total * 100) : 0.0;
    final color = _gradeColor(pct);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3.w,
            height: 36.h,
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
                      child: Text(
                        record.subjectName,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    if (record.status != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 1.h,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(
                            record.status!,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          record.statusLabel,
                          style: TextStyle(
                            fontSize: 9.sp,
                            color: _statusColor(record.status!),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                if (record.studentName.isNotEmpty)
                  Text(
                    record.studentName,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textGray,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              record.mark.toStringAsFixed(0),
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

  Color _gradeColor(double pct) {
    if (pct >= 85) return AppColors.success;
    if (pct >= 70) return AppColors.primary;
    if (pct >= 50) return AppColors.pending;
    return Colors.red;
  }
}
