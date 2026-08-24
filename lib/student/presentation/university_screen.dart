import 'package:studentry/shared/widgets/app_bottom_nav.dart';
import 'package:studentry/student/presentation/lessons_screen.dart';
import 'package:studentry/student/presentation/schedule_screen.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class UniversityScreen extends StatelessWidget {
  final bool embedded;

  const UniversityScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'جامعتي',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.all(20.r),
          children: [
            Center(
              child: Icon(
                Icons.school_outlined,
                size: 64.sp,
                color: AppColors.primary.withValues(alpha: 0.35),
              ),
            ),
            SizedBox(height: 10.h),
            Center(
              child: Text(
                'كل ما يخص دراستك الجامعية',
                style: TextStyle(fontSize: 14.sp, color: AppColors.textGray),
              ),
            ),
            SizedBox(height: 24.h),
            _universityCard(
              context,
              icon: Icons.calendar_month_rounded,
              title: 'برنامجي',
              subtitle: 'عرض البرنامج والمحاضرات الأسبوعية',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScheduleScreen()),
              ),
            ),
            SizedBox(height: 12.h),
            _universityCard(
              context,
              icon: Icons.menu_book_rounded,
              title: 'دروسي',
              subtitle: 'المواد والدروس والملفات الدراسية',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LessonsScreen()),
              ),
            ),
          ],
        ),
        bottomNavigationBar: embedded
            ? null
            : const AppBottomNav(selectedIndex: 2),
      ),
    );
  }

  Widget _universityCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: AppColors.textGray),
          ],
        ),
      ),
    );
  }
}
