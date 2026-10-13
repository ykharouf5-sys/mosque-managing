import 'package:studentry/patients/presentation/providers/patient_providers.dart';
import 'package:studentry/patients/presentation/new_appointment_screen.dart';
import 'package:studentry/patients/presentation/patient_profile_screen.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/widgets/app_bottom_nav.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:studentry/patients/data/patient_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:studentry/shared/widgets/pagination_controls.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:studentry/shared/widgets/refresh_visibility.dart';
import 'package:studentry/shared/data/sync_service.dart';

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
  final bool active;

  const AppointmentsScreen({
    super.key,
    this.embedded = false,
    this.active = true,
  });

  @override
  ConsumerState<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends ConsumerState<AppointmentsScreen> {
  int _selectedDay = DateTime.now().day;
  late int _currentMonth;
  late int _currentYear;
  List<Appointment> _dateAppointments = const [];
  int _page = 1;
  int _lastPage = 1;
  int _requestGeneration = 0;
  bool _loadingDate = false;
  bool _visible = false;

  Future<void> _onDatabaseReload() async {
    if (mounted && _visible) await _loadSelectedDate(page: _page);
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = now.month;
    _currentYear = now.year;
    SyncService.addDbReloadListener(_onDatabaseReload);
    Future.microtask(_loadSelectedDate);
  }

  DateTime get _selectedDate =>
      DateTime(_currentYear, _currentMonth, _selectedDay);

  Future<void> _loadSelectedDate({
    int page = 1,
    bool remote = false,
    bool manual = false,
  }) async {
    final generation = ++_requestGeneration;
    if (mounted) setState(() => _loadingDate = true);
    try {
      final result = await ref
          .read(appointmentListProvider.notifier)
          .loadDatePage(
            _selectedDate,
            page: page,
            remote: remote,
            manual: manual,
          );
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _dateAppointments = result.appointments;
        _page = result.currentPage;
        _lastPage = result.lastPage;
        _loadingDate = false;
      });
    } catch (_) {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loadingDate = false);
      }
    }
  }

  Future<void> _refreshSelectedDate({bool manual = false}) async {
    final date = _selectedDate;
    await _loadSelectedDate(page: _page);
    if (!mounted || !_visible || date != _selectedDate) return;
    await SyncService.syncNow(manual: manual);
    if (!mounted || !_visible) return;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day - 7);
    final end = DateTime(now.year, now.month + 3, now.day);
    // A selected day outside the shared reminder window needs a bounded,
    // paginated REST request, never a full appointments collection.
    final outside = _selectedDate.isBefore(start) || _selectedDate.isAfter(end);
    await _loadSelectedDate(page: _page, remote: outside, manual: manual);
  }

  Future<void> _loadVisibleDate({int page = 1}) async {
    await _loadSelectedDate(page: page);
    if (!mounted || !_visible) return;
    final now = DateTime.now();
    if (_selectedDate.isBefore(DateTime(now.year, now.month, now.day - 7)) ||
        _selectedDate.isAfter(DateTime(now.year, now.month + 3, now.day))) {
      await _loadSelectedDate(page: page, remote: true);
    }
  }

  @override
  void dispose() {
    SyncService.removeDbReloadListener(_onDatabaseReload);
    _requestGeneration++;
    super.dispose();
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
    _loadVisibleDate();
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
    _loadVisibleDate();
  }

  @override
  Widget build(BuildContext context) {
    final appointments = ref.watch(appointmentListProvider);
    return RefreshVisibility(
      active: widget.active,
      onChanged: (visible) {
        _visible = visible;
        if (visible) _refreshSelectedDate();
      },
      child: Scaffold(
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
            IconButton(
              icon: const Icon(
                Icons.notifications_rounded,
                color: AppColors.textDark,
              ),
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildCalendarSection(appointments),
            SizedBox(height: 16.h),
            Expanded(child: _buildAppointmentsSection()),
          ],
        ),
        bottomNavigationBar: widget.embedded
            ? null
            : const AppBottomNav(selectedIndex: 1),
        floatingActionButton: widget.embedded
            ? null
            : FloatingActionButton(
                tooltip: 'موعد جديد',
                onPressed: () async {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          NewAppointmentScreen(initialDate: _selectedDate),
                    ),
                  );
                  if (changed == true) _loadSelectedDate();
                },
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                child: const Icon(Icons.event_available_rounded),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
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
        onTap: () {
          setState(() => _selectedDay = day);
          _loadVisibleDate();
        },
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
      return RefreshIndicator(
        onRefresh: () => _refreshSelectedDate(manual: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(vertical: 24.h),
          children: [
            Center(
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
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _refreshSelectedDate(manual: true),
      color: AppColors.primary,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: appointments.length,
        separatorBuilder: (_, _) => SizedBox(height: 10.h),
        itemBuilder: (context, index) =>
            _buildAppointmentCard(appointments[index]),
      ),
    );
  }

  Widget _buildAppointmentsSection() {
    if (_loadingDate && _dateAppointments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(child: _buildAppointmentsList(_dateAppointments)),
        if (_lastPage > 1 || _loadingDate)
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 10.h),
              child: PaginationControls(
                currentPage: _page,
                lastPage: _lastPage,
                loading: _loadingDate,
                onPrevious: _page > 1
                    ? () => _loadVisibleDate(page: _page - 1)
                    : null,
                onNext: _page < _lastPage
                    ? () => _loadVisibleDate(page: _page + 1)
                    : null,
              ),
            ),
          ),
      ],
    );
  }

  Appointment _withStatus(Appointment appointment, String status) =>
      Appointment(
        id: appointment.id,
        time: appointment.time,
        patientName: appointment.patientName,
        treatment: appointment.treatment,
        status: status,
        patientId: appointment.patientId,
        date: appointment.date,
        reminderSent: appointment.reminderSent,
        notificationSent: appointment.notificationSent,
      );

  Future<void> _editAppointment(Appointment appointment) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NewAppointmentScreen(appointment: appointment),
      ),
    );
    if (changed == true) _loadSelectedDate(page: _page);
  }

  Future<void> _setAppointmentStatus(
    Appointment appointment,
    String status,
  ) async {
    try {
      await ref
          .read(appointmentListProvider.notifier)
          .update(appointment.id, _withStatus(appointment, status));
      await _loadSelectedDate(page: _page);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'ملغي' ? 'تم إلغاء الموعد' : 'تم تأكيد الموعد',
          ),
        ),
      );
    } on AppointmentTimeConflictException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن التأكيد: هذا الوقت محجوز.')),
      );
    }
  }

  Future<void> _cancelAppointment(Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء الموعد؟'),
        content: const Text(
          'سيُعرض الوقت تلقائياً لأول مريض في قائمة انتظار هذا اليوم.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('إلغاء الموعد'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _setAppointmentStatus(appointment, 'ملغي');
  }

  Future<void> _openPatient(Appointment appointment) async {
    final row = await AppDatabase.getPatientById(appointment.patientId);
    final patient = row == null ? null : patientRowToProfile(row);
    if (!mounted) return;
    if (patient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ملف المريض غير متاح حالياً.')),
      );
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => PatientProfileScreen(patient: patient)),
    );
    if (mounted) _loadSelectedDate(page: _page);
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
            child: InkWell(
              onTap: () => _openPatient(apt),
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
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildStatusBadge(apt.status),
          PopupMenuButton<String>(
            tooltip: 'إدارة الموعد',
            onSelected: (action) {
              if (action == 'edit') _editAppointment(apt);
              if (action == 'confirm') _setAppointmentStatus(apt, 'مؤكد');
              if (action == 'cancel') _cancelAppointment(apt);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_calendar_outlined),
                  title: Text('تعديل أو إعادة جدولة'),
                ),
              ),
              if (apt.status != 'مؤكد' && apt.status != 'ملغي')
                const PopupMenuItem(
                  value: 'confirm',
                  child: ListTile(
                    leading: Icon(
                      Icons.check_circle_outline,
                      color: AppColors.success,
                    ),
                    title: Text('تأكيد الموعد'),
                  ),
                ),
              if (apt.status != 'ملغي')
                const PopupMenuItem(
                  value: 'cancel',
                  child: ListTile(
                    leading: Icon(
                      Icons.cancel_outlined,
                      color: AppColors.danger,
                    ),
                    title: Text('إلغاء الموعد'),
                  ),
                ),
            ],
          ),
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
      case 'بانتظار التأكيد':
        color = AppColors.pending;
        break;
      case 'طلب تغيير':
        color = AppColors.pending;
        break;
      case 'قائمة انتظار':
        color = const Color(0xFFE6A700);
        break;
      case 'متاح':
        color = const Color(0xFF0E9F8A);
        break;
      case 'ملغي':
        color = Colors.red;
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
