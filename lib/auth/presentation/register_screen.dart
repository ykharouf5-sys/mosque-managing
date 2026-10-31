import 'package:studentry/auth/presentation/auth_layout.dart';
import 'package:studentry/auth/presentation/auth_mixin.dart';
import 'package:studentry/auth/presentation/otp_verification_screen.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with AuthMixin {
  final _formKey = GlobalKey<FormState>();
  int _step = 0;
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
  Widget build(BuildContext context) => AuthLayout(
    title: 'إنشاء حساب',
    subtitle: _step == 0
        ? 'الخطوة ١ من ٢ · بياناتك الأساسية'
        : 'الخطوة ٢ من ٢ · بيانات الدخول',
    compact: true,
    footer: _buildLoginLink(),
    child: _buildFormCard(),
  );

  Widget _buildFormCard() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (_step == 0) ...[
            _buildAcademicYearSelector(),
            SizedBox(height: 10),
            buildField(
              controller: _nameController,
              hint: 'الاسم الكامل',
              icon: Icons.person_outline,
              keyboardType: TextInputType.name,
              compact: true,
              roomy: true,
            ),
            SizedBox(height: 9),
            buildField(
              controller: _phoneController,
              hint: 'رقم الهاتف',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              compact: true,
              roomy: true,
            ),
            SizedBox(height: 9),
            FilledButton.icon(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  FocusScope.of(context).unfocus();
                  setState(() => _step = 1);
                }
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('متابعة'),
            ),
          ] else ...[
            buildField(
              controller: _emailController,
              hint: 'البريد الإلكتروني',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              compact: true,
              roomy: true,
            ),
            SizedBox(height: 9),
            buildField(
              controller: passwordController,
              hint: 'كلمة المرور',
              icon: Icons.lock_outline,
              isPassword: true,
              compact: true,
              roomy: true,
            ),
            SizedBox(height: 9),
            buildField(
              controller: _confirmController,
              hint: 'تأكيد كلمة المرور',
              icon: Icons.lock_outline,
              isPassword: true,
              isConfirm: true,
              compact: true,
              roomy: true,
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
                onPressed: _isLoading ? null : () => _handleRegister(context),
                icon: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.person_add_alt_1_rounded),
                label: Text(
                  _isLoading ? 'جاري إنشاء الحساب...' : 'إنشاء حساب',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            if (MediaQuery.viewInsetsOf(context).bottom == 0)
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        setState(() => _step = 0);
                      },
                child: const Text('العودة للبيانات الأساسية'),
              ),
          ],
          SizedBox(height: 10),
          if (MediaQuery.viewInsetsOf(context).bottom == 0) ...[
            buildOrDivider(),
            SizedBox(height: 8),
            buildGoogleButton(
              () => signInWithGoogle(selectedRole: _selectedRole),
              compact: true,
            ),
          ],
        ],
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
              style: TextStyle(color: AppColors.authGrey, fontSize: 14),
            ),
            TextSpan(
              text: 'تسجيل الدخول',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
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
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.authFieldBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.authFieldBorder),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedAcademicYear,
          isExpanded: true,
          icon: Icon(Icons.expand_more, color: AppColors.primary, size: 20),
          style: TextStyle(color: AppColors.textDark, fontSize: 14),
          items: _academicYears.map((year) {
            return DropdownMenuItem(
              value: year,
              child: Row(
                children: [
                  Icon(
                    Icons.school_outlined,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'السنة $year',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
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
