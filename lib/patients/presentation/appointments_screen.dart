import 'package:studentry/patients/presentation/providers/patient_providers.dart';
import 'package:studentry/patients/presentation/add_patient_screen.dart';
import 'package:studentry/shared/widgets/app_bottom_nav.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:studentry/patients/data/patient_data.dart';
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
      _selectedDay = _selectedDay
          .clamp(1, _daysInMonth(_currentMonth, _currentYear))
          .toInt();
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
      _selectedDay = _selectedDay
          .clamp(1, _daysInMonth(_currentMonth, _currentYear))
          .toInt();
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
          _buildCalendarSection(appointments),
          SizedBox(height: 16.h),
          Expanded(child: _buildAppointmentsList(selectedAppts)),
        ],
      ),
      bottomNavigationBar: widget.embedded
          ? null
          : const AppBottomNav(selectedIndex: 1),
      floatingActionButton: widget.embedded
          ? null
          : FloatingActionButton(
              tooltip: 'إضافة مريض',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddPatientScreen()),
              ),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.person_add_rounded),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildCalendarSection(List<Appointment> appointments) {
    final appointmentDays = appointments
        .where(
          (appointment) =>
              appointment.date.year == _currentYear &&
              appointment.date.month == _currentMonth,
        )
        .map((appointment) => appointment.date.day)
        .toSet();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.soft,
      ),
      padding: EdgeInsets.fromLTRB(14.w, 5.h, 14.w, 6.h),
      child: Column(
        children: [
          _buildMonthNavigator(),
          SizedBox(height: 4.h),
          _buildWeekDaysHeader(),
          SizedBox(height: 2.h),
          _buildWeekDaysNumbers(appointmentDays),
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
              visualDensity: VisualDensity.compact,
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
              visualDensity: VisualDensity.compact,
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
      children: _weekDays
          .map(
            (d) => Expanded(
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

  Widget _buildWeekDaysNumbers(Set<int> appointmentDays) {
    final days = _daysInMonth(_currentMonth, _currentYear);
    final firstWeekday = _firstWeekday(_currentMonth, _currentYear);
    final now = DateTime.now();
    final isCurrentMonth =
        now.month == _currentMonth && now.year == _currentYear;
    final today = now.day;

    final populatedCells = firstWeekday + days;
    final cellCount = ((populatedCells + 6) ~/ 7) * 7;

    return GridView.builder(
      key: const ValueKey('appointments-calendar-grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisExtent: 33,
      ),
      itemCount: cellCount,
      itemBuilder: (context, index) {
        final day = index - firstWeekday + 1;
        if (day < 1 || day > days) return const SizedBox.shrink();
        return _buildDayCell(
          day,
          isCurrentMonth && day == today,
          appointmentDays.contains(day),
        );
      },
    );
  }

  Widget _buildDayCell(int day, bool isToday, bool hasAppointment) {
    final isSelected = day == _selectedDay;
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$_currentYear-$_currentMonth-$day',
      child: InkWell(
        key: ValueKey('calendar-day-$day'),
        onTap: () => setState(() => _selectedDay = day),
        borderRadius: BorderRadius.circular(20),
        child: Center(
          child: SizedBox.square(
            dimension: 29,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (isToday
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : null),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.22),
                      width: isSelected ? 1.5 : 0.8,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    day.toString(),
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: isSelected || isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? AppColors.textLight
                          : AppColors.textDark,
                    ),
                  ),
                ),
                if (hasAppointment)
                  Positioned(
                    bottom: 2,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
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
