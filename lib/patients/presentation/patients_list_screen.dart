import 'package:animate_do/animate_do.dart';
import 'package:dentalcare/patients/data/notification_service.dart';
import 'package:dentalcare/patients/presentation/providers/patient_providers.dart';
import 'package:dentalcare/shared/widgets/app_bottom_nav.dart';
import 'package:dentalcare/utils/variable_colors.dart';
import 'package:dentalcare/patients/data/patient_data.dart';
import 'package:dentalcare/patients/presentation/patient_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PatientsListScreen extends ConsumerStatefulWidget {
  const PatientsListScreen({super.key});

  @override
  ConsumerState<PatientsListScreen> createState() => _PatientsListScreenState();
}

class _PatientsListScreenState extends ConsumerState<PatientsListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(
      () => ref.read(patientListProvider.notifier).refreshFromApi(),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final notifier = ref.read(patientListProvider.notifier);
    if (!notifier.isLoadingMore &&
        notifier.hasMore &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      notifier.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(patientListProvider);
    final pagination = ref.read(patientListProvider.notifier);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('جميع المرضى'),
      ),
      body: patients.isEmpty
          ? Center(
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
                      Icons.people_outline,
                      size: 40.sp,
                      color: AppColors.textGray.withValues(alpha: 0.5),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'لا يوجد مرضى بعد',
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: AppColors.textGray,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'اضغط على + لإضافة مريض',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textGray,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(patientListProvider.notifier).refreshFromApi();
              },
              color: AppColors.primary,
              child: ListView.separated(
                controller: _scrollController,
                padding: EdgeInsets.all(16.r),
                itemCount: patients.length + (pagination.isLoadingMore ? 1 : 0),
                separatorBuilder: (_, _) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  if (index >= patients.length) {
                    return Padding(
                      padding: EdgeInsets.all(16.r),
                      child: Center(
                        child: SizedBox(
                          width: 24.w,
                          height: 24.h,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    );
                  }
                  final patient = patients[index];
                  return _buildPatientCard(context, patient, index);
                },
              ),
            ),
      bottomNavigationBar: const AppBottomNav(selectedIndex: -1),
    );
  }

  Widget _buildPatientCard(
    BuildContext context,
    PatientProfile patient,
    int index,
  ) {
    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      delay: Duration(milliseconds: index * 60),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.soft,
        ),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PatientProfileScreen(patient: patient),
                ),
              );
            },
            onLongPress: () => _confirmDelete(context, patient),
            child: Padding(
              padding: EdgeInsets.all(14.r),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(4.r),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: CircleAvatar(
                      radius: 26.r,
                      backgroundImage: NetworkImage(patient.photoUrl),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.name,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          patient.phone,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward,
                    color: AppColors.textGrey,
                    size: 20.sp,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PatientProfile patient,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'حذف المريض',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('هل أنت متأكد من حذف ${patient.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: AppColors.textGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final appointments = ref.read(appointmentListProvider);
      for (final a in appointments.where((a) => a.patientId == patient.id)) {
        NotificationService.cancelAppointmentNotification(a);
      }
      ref.read(patientListProvider.notifier).remove(patient.id);
      ref.read(appointmentListProvider.notifier).remove(patient.id);
    }
  }
}
