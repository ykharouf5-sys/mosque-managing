import 'package:studentry/shared/widgets/app_bottom_nav.dart';
import 'package:studentry/shared/widgets/app_drawer.dart';
import 'package:studentry/student/data/subject_models.dart';
import 'package:studentry/student/data/academic_store.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

final List<String> _days = [
  'الأحد',
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
];

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  final AcademicStore _academic = AcademicStore.instance;
  String _selectedDay = _days[0];
  final String _academicYear = 'الأولى';
  @override
  void initState() {
    super.initState();
    _loadAcademicYear();
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

  Future<void> _loadAcademicYear() async {}

  List<StudentSubject> get _dayEnrollments => _academic.enrollments
      .where((e) => e.scheduleDays.contains(_selectedDay))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'برنامجي الجامعي',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      bottomNavigationBar: const AppBottomNav(selectedIndex: 2),
      body: Column(
        children: [
          SizedBox(height: 8.h),
          _buildYearBadge(),
          SizedBox(height: 8.h),
          _buildDaySelector(),
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                const Text(
                  'المواد المسجلة',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_dayEnrollments.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textGray,
                  ),
                ),
                SizedBox(width: 6.w),
                GestureDetector(
                  onTap: () => _showAvailableSubjects(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '+ تسجيل مواد',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Expanded(child: _buildScheduleList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showCustomSubjectDialog(context),
      ),
    );
  }

  Widget _buildYearBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'السنة $_academicYear',
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    return SizedBox(
      height: 44.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        itemCount: _days.length,
        itemBuilder: (_, i) {
          final day = _days[i];
          final isSelected = day == _selectedDay;
          return GestureDetector(
            onTap: () => setState(() => _selectedDay = day),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.divider,
                ),
              ),
              child: Text(
                day,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textDark,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13.sp,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScheduleList() {
    if (_academic.enrollments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 48.sp,
              color: AppColors.textGray.withValues(alpha: 0.3),
            ),
            SizedBox(height: 12.h),
            Text(
              'لم تسجل أي مواد بعد',
              style: TextStyle(fontSize: 14.sp, color: AppColors.textGray),
            ),
            SizedBox(height: 8.h),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('تصفح المواد المتاحة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () => _showAvailableSubjects(context),
            ),
          ],
        ),
      );
    }
    final list = _dayEnrollments;
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 48.sp,
              color: AppColors.textGray.withValues(alpha: 0.3),
            ),
            SizedBox(height: 12.h),
            Text(
              'لا توجد محاضرات في هذا اليوم',
              style: TextStyle(fontSize: 14.sp, color: AppColors.textGray),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      itemCount: list.length,
      itemBuilder: (_, i) => _buildEnrollmentCard(list[i]),
    );
  }

  Widget _buildEnrollmentCard(StudentSubject enrollment) {
    final color = parseColor(enrollment.color);
    final timeStr = enrollment.scheduleTimes.isNotEmpty
        ? enrollment.scheduleTimes.first
        : '';
    return Dismissible(
      key: Key('${enrollment.subjectId}-$_selectedDay'),
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
          _showAcademicError(error);
          return false;
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 4.w,
              height: 60.h,
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
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 12.sp,
                        color: AppColors.textGray,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        enrollment.doctorName.isNotEmpty
                            ? enrollment.doctorName
                            : 'بدون دكتور',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textGray,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Icon(
                        Icons.meeting_room_outlined,
                        size: 12.sp,
                        color: AppColors.textGray,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        enrollment.hall.isNotEmpty ? enrollment.hall : '---',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (timeStr.isNotEmpty)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            SizedBox(width: 8.w),
            GestureDetector(
              onTap: () => _editEnrollmentDialog(context, enrollment),
              child: const Icon(
                Icons.edit_outlined,
                color: AppColors.textGray,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAvailableSubjects(BuildContext context) {
    final subjects = _academic.subjects
        .where((s) => s.academicYear == _academicYear)
        .toList();
    final enrolledIds = _academic.enrollments.map((e) => e.subjectId).toSet();
    final available = subjects
        .where((s) => !enrolledIds.contains(s.id))
        .toList();

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
            final list = available;
            return Container(
              height: 0.65.sh,
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
                  SizedBox(height: 16.h),
                  Text(
                    'المواد المتاحة (السنة $_academicYear)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  if (list.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'لا توجد مواد متاحة للتسجيل',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final s = list[i];
                          final color = parseColor(s.color);
                          return Container(
                            margin: EdgeInsets.only(bottom: 8.h),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: color.withValues(alpha: 0.2),
                                ),
                              ),
                              leading: Container(
                                width: 4.w,
                                height: 40.h,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              title: Text(
                                s.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                s.code,
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14.w,
                                    vertical: 6.h,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  textStyle: TextStyle(fontSize: 12.sp),
                                ),
                                onPressed: () async {
                                  final enrollment = StudentSubject(
                                    subjectId: s.id,
                                    name: s.name,
                                    code: s.code,
                                    academicYear: s.academicYear,
                                    doctorName: s.doctorName,
                                    color: s.color,
                                    scheduleDays: [_selectedDay],
                                    scheduleTimes: ['09:00 - 11:00'],
                                    hall: '',
                                  );
                                  try {
                                    await _academic.addEnrollment(enrollment);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (error) {
                                    _showAcademicError(error);
                                  }
                                },
                                child: const Text('تسجيل'),
                              ),
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

  void _editEnrollmentDialog(BuildContext context, StudentSubject enrollment) {
    final timeC = TextEditingController(
      text: enrollment.scheduleTimes.isNotEmpty
          ? enrollment.scheduleTimes.first
          : '',
    );
    final hallC = TextEditingController(text: enrollment.hall);
    List<String> selectedDays = List.from(enrollment.scheduleDays);

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'تعديل جدول ${enrollment.name}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'الأيام:',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 6.w,
                      children: _days.map((day) {
                        final isSelected = selectedDays.contains(day);
                        return FilterChip(
                          label: Text(day, style: TextStyle(fontSize: 12.sp)),
                          selected: isSelected,
                          selectedColor: AppColors.primary.withValues(
                            alpha: 0.2,
                          ),
                          checkmarkColor: AppColors.primary,
                          onSelected: (v) {
                            setDialogState(() {
                              if (v) {
                                selectedDays.add(day);
                              } else {
                                selectedDays.remove(day);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: timeC,
                      decoration: const InputDecoration(
                        labelText: 'الوقت',
                        hintText: '09:00 - 11:00',
                      ),
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: hallC,
                      decoration: const InputDecoration(
                        labelText: 'القاعة',
                        hintText: 'A101',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () async {
                    final updated = enrollment.copyWith(
                      scheduleDays: selectedDays,
                      scheduleTimes: timeC.text.trim().isNotEmpty
                          ? [timeC.text.trim()]
                          : enrollment.scheduleTimes,
                      hall: hallC.text.trim(),
                    );
                    try {
                      await _academic.updateEnrollment(updated);
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (error) {
                      _showAcademicError(error);
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showCustomSubjectDialog(BuildContext context) {
    final nameC = TextEditingController();
    final codeC = TextEditingController();
    final doctorC = TextEditingController();
    final timeC = TextEditingController();
    final hallC = TextEditingController();
    List<String> selectedDays = [];

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'إضافة مادة مخصصة',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameC,
                      decoration: const InputDecoration(
                        labelText: 'اسم المادة',
                        hintText: 'مادة إضافية',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    SizedBox(height: 10.h),
                    TextField(
                      controller: codeC,
                      decoration: const InputDecoration(
                        labelText: 'كود المادة',
                        hintText: 'اختياري',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    SizedBox(height: 10.h),
                    TextField(
                      controller: doctorC,
                      decoration: const InputDecoration(
                        labelText: 'اسم الدكتور',
                        hintText: 'اختياري',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    SizedBox(height: 10.h),
                    TextField(
                      controller: timeC,
                      decoration: const InputDecoration(
                        labelText: 'الوقت',
                        hintText: '09:00 - 11:00',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    SizedBox(height: 10.h),
                    TextField(
                      controller: hallC,
                      decoration: const InputDecoration(
                        labelText: 'القاعة',
                        hintText: 'A101',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    SizedBox(height: 12.h),
                    const Text(
                      'الأيام:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8.h),
                    Wrap(
                      spacing: 6.w,
                      children: _days.map((day) {
                        final isSelected = selectedDays.contains(day);
                        return FilterChip(
                          label: Text(day, style: TextStyle(fontSize: 12.sp)),
                          selected: isSelected,
                          selectedColor: AppColors.primary.withValues(
                            alpha: 0.2,
                          ),
                          checkmarkColor: AppColors.primary,
                          onSelected: (v) {
                            setDialogState(() {
                              if (v) {
                                selectedDays.add(day);
                              } else {
                                selectedDays.remove(day);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () async {
                    if (nameC.text.trim().isEmpty) return;
                    final id =
                        'custom_${DateTime.now().millisecondsSinceEpoch}';
                    final enrollment = StudentSubject(
                      subjectId: id,
                      name: nameC.text.trim(),
                      code: codeC.text.trim().isNotEmpty
                          ? codeC.text.trim()
                          : 'CUSTOM',
                      academicYear: _academicYear,
                      doctorName: doctorC.text.trim(),
                      color: '#9E9E9E',
                      scheduleDays: selectedDays,
                      scheduleTimes: timeC.text.trim().isNotEmpty
                          ? [timeC.text.trim()]
                          : [],
                      hall: hallC.text.trim(),
                      isCustom: true,
                    );
                    try {
                      await _academic.addEnrollment(enrollment);
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (error) {
                      _showAcademicError(error);
                    }
                  },
                  child: const Text('إضافة'),
                ),
              ],
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
          content: Text('هل أنت متأكد من إلغاء تسجيل "$name"؟'),
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

  void _showAcademicError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('تعذر حفظ التغيير: $error')));
  }
}
