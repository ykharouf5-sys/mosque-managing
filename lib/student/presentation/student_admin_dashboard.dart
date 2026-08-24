import 'package:studentry/student/data/subject_models.dart';
import 'package:studentry/student/presentation/admin_grades_screen.dart';
import 'package:studentry/student/presentation/result_upload_screen.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:studentry/shared/presentation/notification_campaign_screen.dart';
import 'package:file_picker/file_picker.dart';
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
    onSubjectsChanged = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    if (onSubjectsChanged != null) onSubjectsChanged = null;
    super.dispose();
  }

  List<Subject> get _filteredSubjects =>
      dummySubjects.where((s) => s.academicYear == _selectedYear).toList();

  @override
  Widget build(BuildContext context) {
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
          child: const Icon(Icons.add, color: Colors.white),
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
                foregroundColor: Colors.white,
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
      confirmDismiss: (_) => _showDeleteConfirm(context, subject.name),
      onDismissed: (_) => deleteSubject(subject.id),
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
                  Container(
                    width: 4.w,
                    height: 50.h,
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
    List<SubjectLecture> lectures = List.from(subject.lectures);
    final totalC = TextEditingController(text: '${subject.totalLectures}');

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
                  Icon(Icons.list_alt, color: AppColors.primary, size: 22),
                  SizedBox(width: 8.w),
                  Text(
                    'محاضرات ${subject.name}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 0.8.sw,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: totalC,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'عدد المحاضرات',
                              hintText: '20',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 14.h,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            final count = int.tryParse(totalC.text) ?? 0;
                            if (count > 0) {
                              setDialogState(() {
                                lectures = Subject.generateLectures(count);
                              });
                            }
                          },
                          child: const Text(
                            'تطبيق',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Expanded(
                      child: lectures.isEmpty
                          ? Center(
                              child: Text(
                                'أدخل عدد المحاضرات',
                                style: TextStyle(
                                  color: _kGrey,
                                  fontSize: 14.sp,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: lectures.length,
                              itemBuilder: (_, i) {
                                final lecture = lectures[i];
                                return Container(
                                  margin: EdgeInsets.only(bottom: 6.h),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.divider,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ExpansionTile(
                                    tilePadding: EdgeInsets.symmetric(
                                      horizontal: 12.w,
                                    ),
                                    leading: CircleAvatar(
                                      radius: 14.r,
                                      backgroundColor: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      child: Text(
                                        '${lecture.number}',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: TextField(
                                      controller: TextEditingController(
                                        text: lecture.title,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'عنوان المحاضرة',
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      style: TextStyle(fontSize: 13.sp),
                                      onChanged: (v) {
                                        final idx = lectures.indexWhere(
                                          (l) => l.number == lecture.number,
                                        );
                                        if (idx >= 0) {
                                          lectures[idx] = lecture.copyWith(
                                            title: v,
                                          );
                                        }
                                      },
                                    ),
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          12.w,
                                          0,
                                          12.w,
                                          12.h,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            ...lecture.links.asMap().entries.map((
                                              entry,
                                            ) {
                                              final linkIdx = entry.key;
                                              final link = entry.value;
                                              return Padding(
                                                padding: EdgeInsets.only(
                                                  bottom: 6.h,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: TextField(
                                                        controller:
                                                            TextEditingController(
                                                              text: link,
                                                            ),
                                                        decoration: InputDecoration(
                                                          hintText:
                                                              'رابط ${linkIdx + 1}',
                                                          contentPadding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 10,
                                                                vertical: 8,
                                                              ),
                                                          isDense: true,
                                                          border: OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 12.sp,
                                                        ),
                                                        onChanged: (v) {
                                                          final idx = lectures
                                                              .indexWhere(
                                                                (l) =>
                                                                    l.number ==
                                                                    lecture
                                                                        .number,
                                                              );
                                                          if (idx >= 0) {
                                                            final links =
                                                                List<
                                                                  String
                                                                >.from(
                                                                  lectures[idx]
                                                                      .links,
                                                                );
                                                            links[linkIdx] = v;
                                                            lectures[idx] =
                                                                lectures[idx]
                                                                    .copyWith(
                                                                      links:
                                                                          links,
                                                                    );
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                    SizedBox(width: 4.w),
                                                    GestureDetector(
                                                      onTap: () {
                                                        final idx = lectures
                                                            .indexWhere(
                                                              (l) =>
                                                                  l.number ==
                                                                  lecture
                                                                      .number,
                                                            );
                                                        if (idx >= 0) {
                                                          final links =
                                                              List<String>.from(
                                                                lectures[idx]
                                                                    .links,
                                                              );
                                                          links.removeAt(
                                                            linkIdx,
                                                          );
                                                          lectures[idx] =
                                                              lectures[idx]
                                                                  .copyWith(
                                                                    links:
                                                                        links,
                                                                  );
                                                          setDialogState(() {});
                                                        }
                                                      },
                                                      child: Icon(
                                                        Icons.close,
                                                        size: 18,
                                                        color:
                                                            Colors.red.shade300,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                            SizedBox(height: 4.h),
                                            GestureDetector(
                                              onTap: () {
                                                final idx = lectures.indexWhere(
                                                  (l) =>
                                                      l.number ==
                                                      lecture.number,
                                                );
                                                if (idx >= 0) {
                                                  final links =
                                                      List<String>.from(
                                                        lectures[idx].links,
                                                      );
                                                  links.add('');
                                                  lectures[idx] = lectures[idx]
                                                      .copyWith(links: links);
                                                  setDialogState(() {});
                                                }
                                              },
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.add_link,
                                                    size: 16,
                                                    color: AppColors.primary,
                                                  ),
                                                  SizedBox(width: 4.w),
                                                  Text(
                                                    'إضافة رابط',
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
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
                  onPressed: () {
                    Navigator.pop(ctx);
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
      text: '${subject?.totalLectures ?? 20}',
    );
    final isEdit = subject != null;
    String selectedYear = subject?.academicYear ?? _selectedYear;
    String selectedColor = subject?.color ?? '#2196F3';
    String? pdfUrl = subject?.pdfUrl;
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
                      controller: nameC,
                      decoration: const InputDecoration(
                        labelText: 'اسم المادة',
                        hintText: 'مثال: تشريح الأسنان',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    SizedBox(height: 10.h),
                    TextField(
                      controller: codeC,
                      decoration: const InputDecoration(
                        labelText: 'كود المادة',
                        hintText: 'مثال: DEN101',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    SizedBox(height: 10.h),
                    TextField(
                      controller: doctorC,
                      decoration: const InputDecoration(
                        labelText: 'اسم الدكتور',
                        hintText: 'مثال: د. أحمد',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    SizedBox(height: 10.h),
                    TextField(
                      controller: totalC,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'عدد المحاضرات',
                        hintText: '20',
                      ),
                      textDirection: TextDirection.rtl,
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
                                pdfUrl = file.path;
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
                            color: pdfUrl != null
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
                                  : (pdfUrl != null
                                        ? Icons.check_circle
                                        : Icons.picture_as_pdf_outlined),
                              size: 20.sp,
                              color: uploading
                                  ? AppColors.pending
                                  : (pdfUrl != null
                                        ? AppColors.success
                                        : AppColors.textGray),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                uploading
                                    ? 'جاري الرفع...'
                                    : (pdfUrl != null
                                          ? 'تم رفع ملف PDF'
                                          : 'إرفاق ملف PDF للمادة'),
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: uploading
                                      ? AppColors.pending
                                      : (pdfUrl != null
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
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    if (nameC.text.trim().isEmpty ||
                        codeC.text.trim().isEmpty) {
                      return;
                    }
                    final total = int.tryParse(totalC.text) ?? 20;
                    if (isEdit) {
                      updateSubject(
                        subject.id,
                        nameC.text.trim(),
                        codeC.text.trim().toUpperCase(),
                        selectedYear,
                        doctorName: doctorC.text.trim(),
                        color: selectedColor,
                        totalLectures: total,
                        pdfUrl: pdfUrl,
                      );
                    } else {
                      addSubject(
                        nameC.text.trim(),
                        codeC.text.trim().toUpperCase(),
                        selectedYear,
                        doctorName: doctorC.text.trim(),
                        color: selectedColor,
                        totalLectures: total,
                        pdfUrl: pdfUrl,
                      );
                    }
                    Navigator.pop(ctx);
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
