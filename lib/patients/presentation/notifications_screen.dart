import 'package:studentry/patients/data/patient_data.dart';
import 'package:studentry/patients/presentation/providers/patient_providers.dart';
import 'package:studentry/shared/widgets/app_bottom_nav.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(appointmentListProvider);
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayAppts = appointments.where((a) {
      final d = DateTime(a.date.year, a.date.month, a.date.day);
      return d == todayStart;
    }).toList();
    final upcoming = appointments.where((a) {
      final d = DateTime(a.date.year, a.date.month, a.date.day);
      return d.isAfter(todayStart);
    }).toList();
    final past = appointments.where((a) {
      final d = DateTime(a.date.year, a.date.month, a.date.day);
      return d.isBefore(todayStart);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: const AppBottomNav(selectedIndex: 0),
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'الإشعارات',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            ),
          ),
          centerTitle: true,
        ),
        body: past.isEmpty && todayAppts.isEmpty && upcoming.isEmpty
            ? _emptyState(context)
            : ListView(
                padding: EdgeInsets.all(16.r),
                children: [
                  if (todayAppts.isNotEmpty) ...[
                    _sectionHeader('اليوم'),
                    ...todayAppts.map(
                      (a) => _notificationCard(context, a, true),
                    ),
                    SizedBox(height: 16.h),
                  ],
                  if (upcoming.isNotEmpty) ...[
                    _sectionHeader('المواعيد القادمة'),
                    ...upcoming.map(
                      (a) => _notificationCard(context, a, false),
                    ),
                    SizedBox(height: 16.h),
                  ],
                  if (past.isNotEmpty) ...[
                    _sectionHeader('سابقة'),
                    ...past.map((a) => _notificationCard(context, a, true)),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 64.sp,
            color: AppColors.textGray.withValues(alpha: 0.4),
          ),
          SizedBox(height: 16.h),
          Text(
            'لا توجد إشعارات',
            style: TextStyle(color: AppColors.textGray, fontSize: 16.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            'سيتم إعلامك عند اقتراب موعد مريض',
            style: TextStyle(color: AppColors.textGray, fontSize: 13.sp),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 18.h,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
              fontSize: 16.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _notificationCard(BuildContext context, Appointment a, bool isToday) {
    final now = DateTime.now();
    final aptDate = DateTime(a.date.year, a.date.month, a.date.day);
    final isPast = aptDate.isBefore(DateTime(now.year, now.month, now.day));
    final isCurrent = aptDate == DateTime(now.year, now.month, now.day);

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.divider.withValues(alpha: 0.5),
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.h,
            decoration: BoxDecoration(
              color: isPast
                  ? AppColors.textGray.withValues(alpha: 0.1)
                  : isCurrent
                  ? AppColors.primarySurface
                  : AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPast
                  ? Icons.check_circle_outline
                  : Icons.notifications_active_rounded,
              color: isPast ? AppColors.textGray : AppColors.primary,
              size: 22.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.patientName,
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${a.time} • ${a.treatment}',
                  style: TextStyle(color: AppColors.textGray, fontSize: 12.sp),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: isPast
                  ? AppColors.textGray.withValues(alpha: 0.08)
                  : isCurrent
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.primarySurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              a.time,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: isPast
                    ? AppColors.textGray
                    : isCurrent
                    ? AppColors.success
                    : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
