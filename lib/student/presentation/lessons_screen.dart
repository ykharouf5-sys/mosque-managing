import 'subject_content_screen.dart';
import 'package:studentry/shared/widgets/app_bottom_nav.dart';
import 'package:studentry/shared/widgets/app_drawer.dart';
import 'package:studentry/student/data/subject_models.dart';
import 'package:studentry/student/data/academic_store.dart';
import 'package:studentry/student/data/academic_document_service.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'academic_sync_action.dart';
import 'package:studentry/shared/widgets/refresh_visibility.dart';

class LessonsScreen extends ConsumerStatefulWidget {
  const LessonsScreen({super.key});

  @override
  ConsumerState<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends ConsumerState<LessonsScreen> {
  final AcademicStore _academic = AcademicStore.instance;

  @override
  void initState() {
    super.initState();
    _academic.addListener(_onAcademicChanged);
    _academic.load();
  }

  @override
  void dispose() {
    _academic.removeListener(_onAcademicChanged);
    _academic.setViewActive(this, false);
    super.dispose();
  }

  void _onAcademicChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => RefreshVisibility(
    onChanged: (active) => _academic.setViewActive(this, active),
    child: _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'دروسي',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          const AcademicSyncAction(),
          Container(
            margin: EdgeInsets.only(left: 8.w),
            child: IconButton(
              icon: const Icon(
                Icons.bar_chart_rounded,
                color: AppColors.textDark,
              ),
              onPressed: () => _showStatsDialog(context),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(selectedIndex: 2),
      body: _academic.enrollments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 48.sp,
                    color: AppColors.textGray.withValues(alpha: 0.3),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'لم تسجل أي مواد بعد',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textGray,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('تسجيل مواد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () => Navigator.pushNamed(context, '/schedule'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
              itemCount: _academic.enrollments.length,
              itemBuilder: (_, i) => _buildLessonCard(_academic.enrollments[i]),
            ),
    );
  }

  Widget _buildLessonCard(StudentSubject enrollment) {
    final color = parseColor(enrollment.color);
    final progress = enrollment.progress;
    final hasGrade = enrollment.grade > 0;
    final subject = _academic.subjects
        .where((s) => s.id == enrollment.subjectId)
        .firstOrNull;

    return Dismissible(
      key: Key('lesson_${enrollment.subjectId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.w),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) async {
        if (await _confirmRemove(context, enrollment.name) != true) {
          return false;
        }
        try {
          await _academic.removeEnrollment(enrollment);
          return true;
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('تعذر إلغاء التسجيل: $error')),
            );
          }
          return false;
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: subject == null
              ? null
              : () => _showLectureList(context, enrollment, subject),
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
                          enrollment.name,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '${enrollment.code} • ${enrollment.doctorName.isNotEmpty ? enrollment.doctorName : 'بدون دكتور'}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.textGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasGrade)
                    Container(
                      width: 44.w,
                      height: 44.h,
                      decoration: BoxDecoration(
                        color:
                            (enrollment.grade >= 70
                                    ? AppColors.success
                                    : AppColors.danger)
                                .withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${enrollment.grade}',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: enrollment.grade >= 70
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 12.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: color.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6.h,
                ),
              ),
              SizedBox(height: 6.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'تقدم: ${(progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textGray,
                    ),
                  ),
                  Text(
                    '${enrollment.attendedLectures}/${enrollment.totalLectures} محاضرة',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
              if (subject?.pdfUrl != null) ...[
                SizedBox(height: 8.h),
                InkWell(
                  onTap: () async {
                    try {
                      final uri = await const AcademicDocumentService()
                          .subjectUrl(subject!);
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'تعذر فتح ملف المادة. تحقق من الاتصال وحاول مجدداً.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 14.sp,
                          color: const Color(0xFFE53935),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'ملف المادة PDF',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: const Color(0xFFE53935),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.open_in_new,
                          size: 14.sp,
                          color: const Color(0xFFE53935),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (subject != null) ...[
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.playlist_play,
                        size: 14.sp,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'المحاضرات وملخصات ودورات',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_left,
                        size: 16.sp,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showLectureList(
    BuildContext context,
    StudentSubject enrollment,
    Subject subject,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubjectContentScreen(
          subjectId: subject.id,
          enrollmentId: enrollment.enrollmentId,
        ),
      ),
    );
  }

  Future<bool?> _confirmRemove(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'حذف المادة',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text('هل أنت متأكد من حذف "$name"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatsDialog(BuildContext context) {
    final total = _academic.enrollments.length;
    final attended = _academic.enrollments.fold<int>(
      0,
      (s, e) => s + e.attendedLectures,
    );
    final totalLect = _academic.enrollments.fold<int>(
      0,
      (s, e) => s + e.totalLectures,
    );
    final totalCredits = _academic.enrollments.fold<double>(
      0,
      (sum, enrollment) => sum + enrollment.creditHours,
    );
    final avg = total > 0
        ? _academic.enrollments.fold<double>(0, (s, e) => s + e.grade) / total
        : 0.0;

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'إحصائيات الدروس',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _statRow('عدد المواد المسجلة', '$total'),
              SizedBox(height: 8.h),
              _statRow('إجمالي المحاضرات', '$totalLect'),
              SizedBox(height: 8.h),
              _statRow(
                'الساعات المعتمدة المسجلة',
                totalCredits.toStringAsFixed(1),
              ),
              SizedBox(height: 8.h),
              _statRow('إجمالي الحضور', '$attended'),
              SizedBox(height: 8.h),
              _statRow(
                'نسبة الحضور',
                totalLect > 0
                    ? '${(attended / totalLect * 100).toInt()}%'
                    : '0%',
              ),
              SizedBox(height: 8.h),
              _statRow('المعدل', avg.toStringAsFixed(1)),
            ],
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

  Widget _statRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textGray),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
