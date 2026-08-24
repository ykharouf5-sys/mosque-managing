import 'package:dentalcare/auth/presentation/auth_mixin.dart';
import 'package:dentalcare/auth/presentation/otp_verification_screen.dart';
import 'package:dentalcare/shared/data/auth_service.dart';
import 'package:dentalcare/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with AuthMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  final String _selectedRole = 'student';
  String _selectedAcademicYear = 'الأولى';

  final List<String> _academicYears = [
    'الأولى',
    'الثانية',
    'الثالثة',
    'الرابعة',
    'الخامسة',
    'السادسة',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = passwordController.text;
    final name = _nameController.text.trim();
    try {
      final role = _selectedRole;
      final clinicId = '00000000-0000-0000-0000-000000000001';
      final response = await AuthService().signUp(email, password, {
        'clinic_id': clinicId,
        'role': role,
        'full_name': name,
        'phone': _phoneController.text.trim(),
        'academic_year': _selectedAcademicYear,
      });
      if (response.user == null) throw Exception('فشل إنشاء الحساب');
      if (!mounted) return;
      Navigator.pushReplacement(
        this.context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            email: email,
            selectedRole: role,
            purpose: 'email_verification',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF6FBFC),
      body: SafeArea(
        child: Stack(
          children: [
            buildAuthBackdrop(
              assetPath: 'assets/image/auth_register_liquid_glass.png',
              alignment: Alignment.topCenter,
              imageOpacity: 0.30,
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final formWidth = constraints.maxWidth > 600
                    ? 460.0
                    : constraints.maxWidth * 0.94;
                return Padding(
                  padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 6.h),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: formWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildBrandHeader(),
                            SizedBox(height: 14.h),
                            _buildFormCard(),
                            SizedBox(height: 6.h),
                            _buildLoginLink(),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58.r,
              height: 58.r,
              padding: EdgeInsets.all(7.r),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: buildLogoSmall(size: 44),
            ),
            SizedBox(width: 10.w),
            Text(
              'Studentry',
              style: TextStyle(
                color: AppColors.authTextDark,
                fontSize: 23.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Text(
          'إنشاء حساب',
          style: TextStyle(
            color: AppColors.authTextDark,
            fontSize: 24.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          'ابدأ رحلتك الجامعية مع Studentry',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.authGrey,
            fontSize: 13.sp,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B5261).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildAcademicYearSelector(),
            SizedBox(height: 10.h),
            buildField(
              controller: _nameController,
              hint: 'الاسم الكامل',
              icon: Icons.person_outline,
              keyboardType: TextInputType.name,
              compact: true,
              roomy: true,
            ),
            SizedBox(height: 9.h),
            buildField(
              controller: _emailController,
              hint: 'البريد الإلكتروني',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              compact: true,
              roomy: true,
            ),
            SizedBox(height: 9.h),
            buildField(
              controller: _phoneController,
              hint: 'رقم الهاتف',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              compact: true,
              roomy: true,
            ),
            SizedBox(height: 9.h),
            buildField(
              controller: passwordController,
              hint: 'كلمة المرور',
              icon: Icons.lock_outline,
              isPassword: true,
              compact: true,
              roomy: true,
            ),
            SizedBox(height: 9.h),
            buildField(
              controller: _confirmController,
              hint: 'تأكيد كلمة المرور',
              icon: Icons.lock_outline,
              isPassword: true,
              isConfirm: true,
              compact: true,
              roomy: true,
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              height: 60.h,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
                onPressed: _isLoading ? null : () => _handleRegister(context),
                icon: _isLoading
                    ? SizedBox(
                        width: 20.r,
                        height: 20.r,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.person_add_alt_1_rounded),
                label: Text(
                  _isLoading ? 'جاري إنشاء الحساب...' : 'إنشاء حساب',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            SizedBox(height: 10.h),
            buildOrDivider(),
            SizedBox(height: 8.h),
            buildGoogleButton(
              () => signInWithGoogle(selectedRole: _selectedRole),
              compact: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return TextButton(
      onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'لديك حساب بالفعل؟ ',
              style: TextStyle(color: AppColors.authGrey, fontSize: 14.sp),
            ),
            TextSpan(
              text: 'تسجيل الدخول',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcademicYearSelector() {
    return Container(
      height: 50.h,
      decoration: BoxDecoration(
        color: AppColors.authFieldBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.authFieldBorder),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedAcademicYear,
          isExpanded: true,
          icon: Icon(Icons.expand_more, color: AppColors.primary, size: 20.sp),
          style: TextStyle(color: AppColors.textDark, fontSize: 14.sp),
          items: _academicYears.map((year) {
            return DropdownMenuItem(
              value: year,
              child: Row(
                children: [
                  Icon(
                    Icons.school_outlined,
                    color: AppColors.primary,
                    size: 18.sp,
                  ),
                  SizedBox(width: 10.w),
                  Text('السنة $year'),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedAcademicYear = v);
          },
        ),
      ),
    );
  }
}
