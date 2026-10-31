import 'academic_content_editor.dart';
import 'package:studentry/utils/app_input_formatters.dart';
import 'package:studentry/student/data/subject_models.dart';
import 'package:studentry/student/data/academic_store.dart';
import 'package:studentry/student/data/academic_document_service.dart';
import 'package:studentry/student/presentation/admin_grades_screen.dart';
import 'package:studentry/student/presentation/result_upload_screen.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:studentry/shared/presentation/notification_campaign_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'academic_sync_action.dart';
import 'package:studentry/shared/widgets/refresh_visibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const Color _kGrey = Color(0xFF9E9E9E);

class StudentAdminDashboard extends ConsumerStatefulWidget {
  const StudentAdminDashboard({super.key});

  @override
  ConsumerState<StudentAdminDashboard> createState() =>
      _StudentAdminDashboardState();
}

class _StudentAdminDashboardState extends ConsumerState<StudentAdminDashboard> {
  final AcademicStore _academic = AcademicStore.instance;
  final List<String> _academicYears = [
    'الأولى',
    'الثانية',
    'الثالثة',
    'الرابعة',
    'الخامسة',
    'السادسة',
  ];
  String _selectedYear = 'الأولى';

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

  List<Subject> get _filteredSubjects =>
      _academic.subjects.where((s) => s.academicYear == _selectedYear).toList();

  @override
  Widget build(BuildContext context) => RefreshVisibility(
    onChanged: (active) => _academic.setViewActive(this, active),
    child: _buildContent(context),
  );

  Widget _buildContent(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'إدارة المواد الدراسية',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: AppColors.surface,
          elevation: 0,
          actions: [
            const AcademicSyncAction(),
            IconButton(
              icon: const Icon(
                Icons.settings_outlined,
                color: AppColors.textDark,
              ),
              tooltip: 'إعدادات الحساب والخصوصية',
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
            IconButton(
              icon: const Icon(
                Icons.notifications_active_outlined,
                color: AppColors.primary,
              ),
              tooltip: 'إرسال إشعار للطلاب',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationCampaignScreen(
                    managerType: NotificationManagerType.academic,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.upload_file_outlined,
                color: AppColors.textDark,
              ),
              tooltip: 'رفع علامات (قديم)',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminGradesScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.assignment_turned_in_outlined,
                color: AppColors.textDark,
              ),
              tooltip: 'نظام استيراد النتائج',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ResultUploadScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.textDark),
              tooltip: 'تسجيل الخروج',
              onPressed: () => _logout(context),
            ),
          ],
        ),
        body: Column(
          children: [
            SizedBox(height: 8.h),
            _buildYearSelector(),
            SizedBox(height: 12.h),
            Expanded(child: _buildSubjectList()),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: AppColors.onPrimary),
          onPressed: () => _showSubjectDialog(context, null),
        ),
      ),
    );
  }

  void _logout(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Widget _buildYearSelector() {
    return SizedBox(
      height: 48.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        itemCount: _academicYears.length,
        itemBuilder: (_, i) {
          final year = _academicYears[i];
          final isSelected = year == _selectedYear;
          return GestureDetector(
            onTap: () => setState(() => _selectedYear = year),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.divider,
                ),
              ),
              child: Text(
                'السنة $year',
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

  Widget _buildSubjectList() {
    final subjects = _filteredSubjects;
    if (subjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 48.sp,
              color: _kGrey.withValues(alpha: 0.3),
            ),
            SizedBox(height: 12.h),
            Text(
              'لا توجد مواد للسنة $_selectedYear',
              style: TextStyle(color: _kGrey, fontSize: 14.sp),
            ),
            SizedBox(height: 12.h),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة مادة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () => _showSubjectDialog(context, null),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      itemCount: subjects.length,
      itemBuilder: (_, i) => _buildSubjectCard(context, subjects[i]),
    );
  }

  Widget _buildSubjectCard(BuildContext context, Subject subject) {
    final color = parseColor(subject.color);
    return Dismissible(
      key: Key(subject.id),
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
        if (await _showDeleteConfirm(context, subject.name) != true) {
          return false;
        }
        try {
          await _academic.deleteSubject(subject.id);
          return true;
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('تعذر حذف المادة: $error')));
          }
          return false;
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showLectureManager(context, subject),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.menu_book_outlined, color: color, size: 22),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.name,
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
                              Icons.code_outlined,
                              size: 12.sp,
                              color: AppColors.textGray,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              subject.code,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.textGray,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            if (subject.doctorName.isNotEmpty) ...[
                              Icon(
                                Icons.person_outline,
                                size: 12.sp,
                                color: AppColors.textGray,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                subject.doctorName,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: AppColors.textGray,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '${subject.totalLectures} محاضرة',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${subject.creditHours.toStringAsFixed(1)} ساعة معتمدة',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: AppColors.textGray,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'إدارة المحاضرات',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: 8.w),
                  Icon(Icons.chevron_left, color: _kGrey, size: 20.sp),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLectureManager(BuildContext context, Subject subject) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AcademicContentEditor(subject: subject),
      ),
    );
  }

  Future<bool?> _showDeleteConfirm(BuildContext context, String name) {
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

  void _showSubjectDialog(BuildContext context, Subject? subject) {
    final nameC = TextEditingController(text: subject?.name ?? '');
    final codeC = TextEditingController(text: subject?.code ?? '');
    final doctorC = TextEditingController(text: subject?.doctorName ?? '');
    final totalC = TextEditingController(
      text: '${subject?.publishedLectures.length ?? 0}',
    );
    final theoreticalC = TextEditingController(
      text: '${subject?.theoreticalHours ?? 0}',
    );
    final practicalC = TextEditingController(
      text: '${subject?.practicalHours ?? 0}',
    );
    final isEdit = subject != null;
    String selectedYear = subject?.academicYear ?? _selectedYear;
    String selectedColor = subject?.color ?? '#2196F3';
    String? pdfReference = subject?.pdfReference;
    bool uploading = false;

    final colorOptions = [
      {'label': 'أزرق', 'value': '#2196F3'},
      {'label': 'أخضر', 'value': '#4CAF50'},
      {'label': 'برتقالي', 'value': '#FF9800'},
      {'label': 'بنفسجي', 'value': '#9C27B0'},
      {'label': 'وردي', 'value': '#E91E63'},
      {'label': 'سيان', 'value': '#00BCD4'},
      {'label': 'كحلي', 'value': '#3F51B5'},
      {'label': 'أحمر', 'value': '#FF5722'},
    ];

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
              title: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.menu_book_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    isEdit ? 'تعديل المادة' : 'إضافة مادة',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 17.sp,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      inputFormatters: AppInputFormatters.text(160),
                      textAlignVertical: TextAlignVertical.center,
                      controller: nameC,
                      decoration: const InputDecoration(
                        labelText: 'اسم المادة',
                        hintText: 'مثال: تشريح الأسنان',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    SizedBox(height: 10.h),
                    TextField(
                      inputFormatters: AppInputFormatters.text(80),
                      textAlignVertical: TextAlignVertical.center,
                      controller: codeC,
                      decoration: const InputDecoration(
                        labelText: 'كود المادة',
                        hintText: 'مثال: DEN101',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    SizedBox(height: 10.h),
                    TextField(
                      inputFormatters: AppInputFormatters.text(160),
                      textAlignVertical: TextAlignVertical.center,
                      controller: doctorC,
                      decoration: const InputDecoration(
                        labelText: 'اسم الدكتور',
                        hintText: 'مثال: د. أحمد',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    SizedBox(height: 10.h),
                    TextField(
                      inputFormatters: AppInputFormatters.integer(
                        digits: 3,
                        max: 500,
                      ),
                      textAlignVertical: TextAlignVertical.center,
                      controller: totalC,
                      readOnly: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText:
                            'عدد المحاضرات المنشورة (تُضاف من إدارة المحاضرات)',
                        hintText: '20',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            inputFormatters: AppInputFormatters.integer(
                              digits: 2,
                              max: 40,
                            ),
                            textAlignVertical: TextAlignVertical.center,
                            controller: theoreticalC,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'نظري أسبوعياً',
                              suffixText: 'ساعة',
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: TextField(
                            inputFormatters: AppInputFormatters.integer(
                              digits: 2,
                              max: 80,
                            ),
                            textAlignVertical: TextAlignVertical.center,
                            controller: practicalC,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'عملي أسبوعياً',
                              suffixText: 'ساعة',
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 6.h),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'الساعات المعتمدة = النظري + نصف العملي',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 11.sp,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    DropdownButtonFormField<String>(
                      initialValue: selectedYear,
                      decoration: const InputDecoration(
                        labelText: 'السنة الدراسية',
                      ),
                      items: _academicYears
                          .map(
                            (y) => DropdownMenuItem(
                              value: y,
                              child: Text('السنة $y'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedYear = v!),
                    ),
                    SizedBox(height: 10.h),
                    DropdownButtonFormField<String>(
                      initialValue: selectedColor,
                      decoration: const InputDecoration(labelText: 'اللون'),
                      items: colorOptions
                          .map(
                            (c) => DropdownMenuItem(
                              value: c['value'],
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: parseColor(c['value']!),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(c['label']!),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedColor = v!),
                    ),
                    SizedBox(height: 10.h),
                    InkWell(
                      onTap: uploading
                          ? null
                          : () async {
                              final result = await FilePicker.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['pdf'],
                              );
                              if (result == null || result.files.isEmpty) {
                                return;
                              }
                              final file = result.files.first;
                              if (file.path == null) return;
                              setDialogState(() => uploading = true);
                              try {
                                pdfReference =
                                    await const AcademicDocumentService()
                                        .uploadPdf(file.path!);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('فشل رفع الملف: $e'),
                                    ),
                                  );
                                }
                              } finally {
                                setDialogState(() => uploading = false);
                              }
                            },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 12.h,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: pdfReference != null
                                ? AppColors.success
                                : AppColors.divider,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              uploading
                                  ? Icons.hourglass_top
                                  : (pdfReference != null
                                        ? Icons.check_circle
                                        : Icons.picture_as_pdf_outlined),
                              size: 20.sp,
                              color: uploading
                                  ? AppColors.pending
                                  : (pdfReference != null
                                        ? AppColors.success
                                        : AppColors.textGray),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                uploading
                                    ? 'جاري الرفع...'
                                    : (pdfReference != null
                                          ? 'تم رفع ملف PDF'
                                          : 'إرفاق ملف PDF للمادة'),
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: uploading
                                      ? AppColors.pending
                                      : (pdfReference != null
                                            ? AppColors.success
                                            : AppColors.textGray),
                                ),
                              ),
                            ),
                          ],
                        ),
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
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () async {
                    if (nameC.text.trim().isEmpty ||
                        codeC.text.trim().isEmpty) {
                      return;
                    }
                    final theoretical = int.tryParse(theoreticalC.text) ?? 0;
                    final practical = int.tryParse(practicalC.text) ?? 0;
                    if (theoretical < 0 || practical < 0) return;
                    try {
                      if (isEdit) {
                        final lectures = subject.lectures;
                        await _academic.updateSubject(
                          subject.copyWith(
                            name: nameC.text.trim(),
                            code: codeC.text.trim().toUpperCase(),
                            academicYear: selectedYear,
                            doctorName: doctorC.text.trim(),
                            color: selectedColor,
                            totalLectures: subject.publishedLectures.length,
                            theoreticalHours: theoretical,
                            practicalHours: practical,
                            creditHours: theoretical + (practical / 2),
                            lectures: lectures,
                            pdfReference: pdfReference,
                          ),
                        );
                      } else {
                        await _academic.addSubject(
                          name: nameC.text.trim(),
                          code: codeC.text.trim().toUpperCase(),
                          academicYear: selectedYear,
                          doctorName: doctorC.text.trim(),
                          color: selectedColor,
                          totalLectures: 0,
                          theoreticalHours: theoretical,
                          practicalHours: practical,
                          pdfUrl: pdfReference,
                        );
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (error) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('تعذر حفظ المادة: $error')),
                        );
                      }
                    }
                  },
                  child: Text(isEdit ? 'حفظ' : 'إضافة'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
