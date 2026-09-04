import 'package:animate_do/animate_do.dart';
import 'package:studentry/shared/widgets/app_bottom_nav.dart';
import 'package:studentry/shared/widgets/app_drawer.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/patients/data/patient_data.dart';
import 'package:studentry/patients/presentation/patients_list_screen.dart';
import 'package:studentry/patients/presentation/add_patient_screen.dart';
import 'package:studentry/patients/presentation/patient_profile_screen.dart';
import 'package:studentry/patients/presentation/providers/patient_providers.dart';
import 'package:studentry/student/presentation/student_grades_screen.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' hide TextDirection;

class StudentHomeScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const StudentHomeScreen({super.key, this.embedded = false});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _refreshTodayData());
  }

  Future<void> _refreshTodayData({bool force = false}) async {
    final changed = await ref
        .read(patientListProvider.notifier)
        .refreshFromApi(force: force);
    if (!changed) {
      await ref.read(appointmentListProvider.notifier).loadFromDb();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      drawer: const AppDrawer(),
      drawerEnableOpenDragGesture: !widget.embedded,
      body: RefreshIndicator(
        onRefresh: () => _refreshTodayData(force: true),
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8.h),
              _buildWelcomeSection(),
              SizedBox(height: 20.h),
              _buildTodaySection(),
              SizedBox(height: 24.h),
              _buildQuickActions(context),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.embedded
          ? null
          : const AppBottomNav(selectedIndex: 0),
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

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: AppColors.background,
    elevation: 0,
    scrolledUnderElevation: 1,
    leading: Builder(
      builder: (ctx) => IconButton(
        icon: const Icon(Icons.menu, color: AppColors.textDark),
        onPressed: () => Scaffold.of(ctx).openDrawer(),
      ),
    ),
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8.w,
          height: 8.h,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8.w),
        const Text(
          'الرئيسية',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    ),
  );

  Widget _buildWelcomeSection() {
    final now = DateTime.now();
    final savedName = AuthService().fullName?.trim();
    final studentName = savedName == null || savedName.isEmpty
        ? 'طالب طب أسنان'
        : savedName;
    final weekDays = [
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];
    final dateStr =
        '${weekDays[now.weekday % 7]} ${now.day} ${DateFormat('MMMM yyyy', 'ar').format(now)}';
    return FadeInDown(
      duration: const Duration(milliseconds: 600),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.85),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.waving_hand, color: Colors.white, size: 24),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'مرحباً • $studentName',
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'رافق دراستك الجامعية كل يوم',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              dateStr,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              width: 40.w,
              height: 3.h,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) => FadeInUp(
    duration: const Duration(milliseconds: 500),
    delay: const Duration(milliseconds: 200),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الوصول السريع',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        SizedBox(height: 12.h),
        Wrap(
          spacing: 12.w,
          runSpacing: 12.h,
          children: [
            _sizedAction(
              context,
              Icons.calendar_month_rounded,
              'برنامجي',
              AppColors.primary,
              () => Navigator.pushNamed(context, '/schedule'),
            ),
            _sizedAction(
              context,
              Icons.school_rounded,
              'جامعتي',
              const Color(0xFFFF9800),
              () => Navigator.pushNamed(context, '/university'),
            ),
            _sizedAction(
              context,
              Icons.store_rounded,
              'المتجر',
              const Color(0xFF4CAF50),
              () => Navigator.pushNamed(context, '/store'),
            ),
            _sizedAction(
              context,
              Icons.score_outlined,
              'علاماتي',
              const Color(0xFF9C27B0),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentGradesScreen()),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildTodaySection() {
    final now = DateTime.now();
    bool isToday(DateTime date) =>
        date.year == now.year && date.month == now.month && date.day == now.day;
    final appointments =
        ref
            .watch(appointmentListProvider)
            .where((appointment) => isToday(appointment.date))
            .toList()
          ..sort(
            (a, b) => a.appointmentDateTime.compareTo(b.appointmentDateTime),
          );
    final ids = appointments
        .map((appointment) => appointment.patientId)
        .toSet();
    final patients = ref.watch(patientListProvider).where((patient) {
      return ids.contains(patient.id) ||
          appointments.any(
            (appointment) => appointment.patientName == patient.name,
          );
    }).toList();

    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _todayTitle('مرضى اليوم', patients.length)),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PatientsListScreen()),
                ),
                icon: const Icon(Icons.groups_rounded, size: 18),
                label: const Text('عرض المرضى'),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          if (patients.isEmpty)
            _emptyToday('لا يوجد مرضى اليوم')
          else
            ...patients.map((patient) {
              final appointment = appointments.cast<Appointment?>().firstWhere(
                (item) =>
                    item?.patientId == patient.id ||
                    item?.patientName == patient.name,
                orElse: () => null,
              );
              return _patientCard(patient, appointment);
            }),
        ],
      ),
    );
  }

  Widget _todayTitle(String title, int count) => Row(
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
      ),
      SizedBox(width: 8.w),
      Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  );

  Widget _patientCard(PatientProfile patient, Appointment? appointment) =>
      Container(
        margin: EdgeInsets.only(bottom: 9.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFF2FBFC)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PatientProfileScreen(patient: patient),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(13.r),
            child: Row(
              children: [
                Container(
                  width: 48.r,
                  height: 48.r,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(15.r),
                  ),
                  child: Center(
                    child: Text(
                      patient.name.trim().isEmpty
                          ? '؟'
                          : patient.name.trim()[0],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Wrap(
                        spacing: 10.w,
                        runSpacing: 4.h,
                        children: [
                          _patientDetail(
                            Icons.schedule_rounded,
                            appointment?.time ?? 'بدون وقت',
                          ),
                          _patientDetail(
                            Icons.medical_services_outlined,
                            appointment?.treatment.isNotEmpty == true
                                ? appointment!.treatment
                                : 'مراجعة',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: const Text(
                    'اليوم',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _patientDetail(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15.sp, color: AppColors.textGray),
      SizedBox(width: 4.w),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 105.w),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.sp, color: AppColors.textGray),
        ),
      ),
    ],
  );

  Widget _emptyToday(String message) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(16.r),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.textGray),
    ),
  );

  Widget _sizedAction(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) => SizedBox(
    width: (MediaQuery.of(context).size.width - 56.w) / 2,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: color, size: 24.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
