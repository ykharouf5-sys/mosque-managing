import 'package:dentalcare/patients/presentation/providers/patient_providers.dart';
import 'package:dentalcare/shared/widgets/app_bottom_nav.dart';
import 'package:dentalcare/utils/variable_colors.dart';
import 'package:dentalcare/patients/data/patient_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' hide TextDirection;

const List<String> _weekDays = [
  'الأحد',
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
];

class AppointmentsScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const AppointmentsScreen({super.key, this.embedded = false});

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  int _selectedDay = DateTime.now().day;
  late int _currentMonth;
  late int _currentYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = now.month;
    _currentYear = now.year;
  }

  int _daysInMonth(int month, int year) => DateTime(year, month + 1, 0).day;
  int _firstWeekday(int month, int year) =>
      DateTime(year, month, 1).weekday % 7;

  void _prevMonth() {
    setState(() {
      if (_currentMonth == 1) {
        _currentMonth = 12;
        _currentYear--;
      } else {
        _currentMonth--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_currentMonth == 12) {
        _currentMonth = 1;
        _currentYear++;
      } else {
        _currentMonth++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appointments = ref.watch(appointmentListProvider);
    final selectedDate = DateTime(_currentYear, _currentMonth, _selectedDay);
    final selectedAppts = appointments.where((a) {
      final aptDate = DateTime(a.date.year, a.date.month, a.date.day);
      return aptDate == selectedDate;
    }).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: widget.embedded
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                onPressed: () => Navigator.pop(context),
              ),
        title: const Text('المواعيد'),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_rounded,
                  color: AppColors.textDark,
                ),
                onPressed: () => Navigator.pushNamed(context, '/notifications'),
              ),
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '1',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCalendarSection(),
          SizedBox(height: 16.h),
          Expanded(child: _buildAppointmentsList(selectedAppts)),
        ],
      ),
      bottomNavigationBar: widget.embedded
          ? null
          : const AppBottomNav(selectedIndex: 1, showAddButton: true),
    );
  }

  Widget _buildCalendarSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.soft,
      ),
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: Column(
        children: [
          _buildMonthNavigator(),
          SizedBox(height: 8.h),
          _buildWeekDaysHeader(),
          SizedBox(height: 2.h),
          _buildWeekDaysNumbers(),
        ],
      ),
    );
  }

  Widget _buildMonthNavigator() {
    final monthName = DateFormat(
      'MMMM yyyy',
      'ar',
    ).format(DateTime(_currentYear, _currentMonth));
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppColors.primary),
              onPressed: _prevMonth,
            ),
            Text(
              monthName,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left, color: AppColors.primary),
              onPressed: _nextMonth,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Center(
          child: Container(
            height: 3,
            width: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekDaysHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: _weekDays
          .map(
            (d) => SizedBox(
              width: 30.w,
              child: Text(
                d,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.sp,
                  color: AppColors.textGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildWeekDaysNumbers() {
    final days = _daysInMonth(_currentMonth, _currentYear);
    final firstWeekday = _firstWeekday(_currentMonth, _currentYear);
    final now = DateTime.now();
    final isCurrentMonth =
        now.month == _currentMonth && now.year == _currentYear;
    final today = now.day;

    return Wrap(
      children: [
        for (int i = 0; i < firstWeekday; i++)
          SizedBox(width: 30.w, height: 32.h),
        for (int day = 1; day <= days; day++)
          _buildDayCell(day, isCurrentMonth && day == today),
      ],
    );
  }

  Widget _buildDayCell(int day, bool isToday) {
    final isSelected = day == _selectedDay;
    return GestureDetector(
      onTap: () => setState(() => _selectedDay = day),
      child: Container(
        width: 30.w,
        height: 32.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : (isToday ? AppColors.primary.withValues(alpha: 0.12) : null),
          shape: BoxShape.circle,
        ),
        child: Text(
          day.toString(),
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: isSelected || isToday
                ? FontWeight.bold
                : FontWeight.normal,
            color: isSelected ? AppColors.textLight : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentsList(List<Appointment> appointments) {
    if (appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.primary.withValues(alpha: 0.02),
                  ],
                ),
              ),
              child: Icon(
                Icons.event_busy,
                size: 40.sp,
                color: AppColors.textGray.withValues(alpha: 0.5),
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'لا توجد مواعيد لهذا اليوم',
              style: TextStyle(fontSize: 15.sp, color: AppColors.textGray),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async =>
          ref.read(appointmentListProvider.notifier).refresh(),
      color: AppColors.primary,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: appointments.length,
        separatorBuilder: (_, _) => SizedBox(height: 10.h),
        itemBuilder: (context, index) =>
            _buildAppointmentCard(appointments[index]),
      ),
    );
  }

  Widget _buildAppointmentCard(Appointment apt) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Container(
            width: 50.w,
            height: 50.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              apt.time,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  apt.patientName,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  apt.treatment,
                  style: TextStyle(fontSize: 13.sp, color: AppColors.textGrey),
                ),
              ],
            ),
          ),
          _buildStatusBadge(apt.status),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'مؤكد':
        color = AppColors.success;
        break;
      case 'باتنظار':
        color = AppColors.pending;
        break;
      default:
        color = AppColors.textGrey;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
