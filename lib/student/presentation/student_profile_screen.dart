import 'package:dentalcare/shared/providers/auth_provider.dart';
import 'package:dentalcare/shared/data/auth_service.dart';
import 'package:dentalcare/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class StudentProfileScreen extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() =>
      _StudentProfileScreenState();
}

class _StudentProfileScreenState extends ConsumerState<StudentProfileScreen> {
  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _univC = TextEditingController();
  final _studentIdC = TextEditingController();
  String _academicYear = 'الأولى';
  bool _saving = false;

  final List<String> _academicYears = [
    'الأولى',
    'الثانية',
    'الثالثة',
    'الرابعة',
    'الخامسة',
    'السادسة',
  ];

  @override
  void initState() {
    super.initState();
    final auth = AuthService();
    _nameC.text = auth.fullName ?? '';
    _phoneC.text = auth.phone ?? '';
    _univC.text = auth.university ?? '';
    _studentIdC.text = auth.examNumber ?? '';
    if (_academicYears.contains(auth.academicYear)) {
      _academicYear = auth.academicYear!;
    }
  }

  @override
  void dispose() {
    _nameC.dispose();
    _phoneC.dispose();
    _univC.dispose();
    _studentIdC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final userId = ref.read(authProvider).userId;
    if (userId == null) return;
    if (_nameC.text.trim().isEmpty) return;
    if (_studentIdC.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال الرقم الامتحاني')),
      );
      setState(() => _saving = false);
      return;
    }

    setState(() => _saving = true);

    try {
      await AuthService().updateStudentProfile(
        fullName: _nameC.text,
        phone: _phoneC.text,
        university: _univC.text,
        academicYear: _academicYear,
        examNumber: _studentIdC.text,
      );
      ref.read(authProvider.notifier).setAuth(userId, 'student');
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/student-home',
          (_) => false,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر حفظ الملف: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          title: const Text(
            'إعداد ملف الطالب',
            style: TextStyle(
              color: AppColors.textDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(20.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: EdgeInsets.all(16.r),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school,
                    color: AppColors.primary,
                    size: 48,
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Center(
                child: Text(
                  'أهلاً بك في تطبيق عيادة الأسنان',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              SizedBox(height: 4.h),
              Center(
                child: Text(
                  'يرجى إكمال بياناتك للبدء',
                  style: TextStyle(fontSize: 13.sp, color: AppColors.textGray),
                ),
              ),
              SizedBox(height: 24.h),
              TextField(
                controller: _nameC,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل *',
                  hintText: 'مثال: أحمد محمد',
                ),
                textDirection: TextDirection.rtl,
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _phoneC,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  hintText: 'مثال: 0912345678',
                ),
                textDirection: TextDirection.rtl,
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _univC,
                decoration: const InputDecoration(
                  labelText: 'الجامعة',
                  hintText: 'مثال: جامعة دمشق',
                ),
                textDirection: TextDirection.rtl,
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _studentIdC,
                decoration: InputDecoration(
                  labelText: 'الرقم الامتحاني / الرقم الجامعي *',
                  hintText: 'مثال: 2021001',
                  helperText: 'مطلوب لعرض العلامات',
                  helperStyle: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11.sp,
                  ),
                ),
                textDirection: TextDirection.rtl,
              ),
              SizedBox(height: 12.h),
              DropdownButtonFormField<String>(
                initialValue: _academicYear,
                decoration: const InputDecoration(labelText: 'السنة الدراسية'),
                items: _academicYears
                    .map(
                      (y) =>
                          DropdownMenuItem(value: y, child: Text('السنة $y')),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _academicYear = v!),
              ),
              SizedBox(height: 28.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'حفظ ومتابعة',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
