import 'package:studentry/shared/widgets/app_bottom_nav.dart';
import 'package:studentry/shared/widgets/app_drawer.dart';
import 'package:studentry/student/data/subject_models.dart';
import 'package:studentry/student/data/academic_store.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

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
    super.dispose();
  }

  void _onAcademicChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
                      foregroundColor: Colors.white,
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
    final hasLectures = subject != null && subject.lectures.isNotEmpty;

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
          onTap: hasLectures
              ? () => _showLectureList(context, enrollment, subject)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4.w,
                    height: 40.h,
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
                    final uri = Uri.tryParse(subject!.pdfUrl!);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
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
              if (hasLectures) ...[
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
                        'عرض المحاضرات والروابط',
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
    final lectures = subject.lectures;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            final viewed = enrollment.viewedLectures;
            return Container(
              height: 0.85.sh,
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Text(
                        subject.name,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${viewed.length}/${lectures.length}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: lectures.isNotEmpty
                          ? viewed.length / lectures.length
                          : 0,
                      backgroundColor: AppColors.divider,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                      minHeight: 4.h,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Expanded(
                    child: ListView.builder(
                      itemCount: lectures.length,
                      itemBuilder: (_, i) {
                        final lecture = lectures[i];
                        final isViewed = viewed.contains(lecture.number);
                        final hasLinks = lecture.links.any(
                          (l) => l.trim().isNotEmpty,
                        );
                        return Container(
                          margin: EdgeInsets.only(bottom: 8.h),
                          decoration: BoxDecoration(
                            color: isViewed
                                ? AppColors.primary.withValues(alpha: 0.04)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isViewed
                                  ? AppColors.primary.withValues(alpha: 0.3)
                                  : AppColors.divider,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 2.h,
                                ),
                                leading: CircleAvatar(
                                  radius: 16.r,
                                  backgroundColor: isViewed
                                      ? AppColors.primary
                                      : AppColors.divider,
                                  child: isViewed
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 16,
                                        )
                                      : Text(
                                          '${lecture.number}',
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                ),
                                title: Text(
                                  lecture.title.isNotEmpty
                                      ? lecture.title
                                      : 'محاضرة ${lecture.number}',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: isViewed
                                        ? AppColors.primary
                                        : AppColors.textDark,
                                  ),
                                ),
                                trailing: hasLinks
                                    ? Icon(
                                        Icons.link,
                                        size: 18.sp,
                                        color: isViewed
                                            ? AppColors.primary
                                            : _kGrey,
                                      )
                                    : null,
                              ),
                              if (hasLinks)
                                Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    12.w,
                                    0,
                                    12.w,
                                    10.h,
                                  ),
                                  child: Wrap(
                                    spacing: 6.w,
                                    runSpacing: 6.h,
                                    children: lecture.links
                                        .where((l) => l.trim().isNotEmpty)
                                        .map((link) {
                                          return InkWell(
                                            onTap: () async {
                                              var url = link.trim();
                                              if (!url.startsWith('http://') &&
                                                  !url.startsWith('https://')) {
                                                url = 'https://$url';
                                              }
                                              final uri = Uri.tryParse(url);
                                              if (uri != null) {
                                                try {
                                                  await launchUrl(
                                                    uri,
                                                    mode: LaunchMode
                                                        .externalApplication,
                                                  );
                                                } catch (_) {}
                                              }
                                              try {
                                                await _academic
                                                    .markLectureViewed(
                                                      enrollment,
                                                      lecture.number,
                                                    );
                                              } catch (error) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'تعذر حفظ تقدم المحاضرة: $error',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                              if (context.mounted) {
                                                setSheetState(() {});
                                                if (mounted) setState(() {});
                                              }
                                            },
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 10.w,
                                                vertical: 6.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isViewed
                                                    ? AppColors.primary
                                                          .withValues(
                                                            alpha: 0.1,
                                                          )
                                                    : AppColors.primarySurface,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.2),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.open_in_new,
                                                    size: 12.sp,
                                                    color: AppColors.primary,
                                                  ),
                                                  SizedBox(width: 4.w),
                                                  Text(
                                                    'رابط ${lecture.links.takeWhile((l) => l.trim().isNotEmpty).toList().indexOf(link) + 1}',
                                                    style: TextStyle(
                                                      fontSize: 11.sp,
                                                      color: AppColors.primary,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        })
                                        .toList(),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
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

const Color _kGrey = Color(0xFF9E9E9E);
