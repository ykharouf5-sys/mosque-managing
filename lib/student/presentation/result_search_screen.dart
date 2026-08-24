import 'package:studentry/student/data/result_models.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ResultSearchScreen extends ConsumerStatefulWidget {
  const ResultSearchScreen({super.key});

  @override
  ConsumerState<ResultSearchScreen> createState() => _ResultSearchScreenState();
}

class _ResultSearchScreenState extends ConsumerState<ResultSearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<ResultRecord> _results = [];
  bool _loading = false;
  bool _searched = false;
  List<String> _storedExamNumbers = [];
  bool _loadingSamples = false;

  @override
  void initState() {
    super.initState();
    _fetchSampleExamNumbers();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _searched = true;
      _storedExamNumbers = [];
    });

    try {
      final results = <ResultRecord>[];
      if (mounted) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
      if (results.isEmpty && mounted) {
        _fetchSampleExamNumbers();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في البحث: $e')));
      }
    }
  }

  Future<void> _fetchSampleExamNumbers() async {
    setState(() => _loadingSamples = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'البحث عن النتائج',
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
            _buildSearchBar(),
            Expanded(child: _buildResults()),
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
          hintText: 'أدخل الرقم الامتحاني',
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
                    setState(() {
                      _results = [];
                      _searched = false;
                    });
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
        onSubmitted: (_) => _search(),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildResults() {
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
              Icons.search_rounded,
              size: 80.sp,
              color: AppColors.textGray.withValues(alpha: 0.3),
            ),
            SizedBox(height: 16.h),
            Text(
              'ابحث برقمك الامتحاني',
              style: TextStyle(fontSize: 16.sp, color: AppColors.textGray),
            ),
            SizedBox(height: 8.h),
            Text(
              'أدخل رقمك الامتحاني لعرض جميع نتائجك',
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
      return Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
              if (_loadingSamples)
                Padding(
                  padding: EdgeInsets.only(top: 20.h),
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              if (_storedExamNumbers.isNotEmpty) ...[
                SizedBox(height: 20.h),
                _buildStoredNumbersSection(),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildSummaryCard(),
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

  Widget _buildSummaryCard() {
    final avg = _results.isEmpty
        ? 0.0
        : _results.fold<double>(0, (s, r) => s + r.mark) / _results.length;

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
                  avg.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
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
                      child: Text(
                        record.subjectName,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
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
