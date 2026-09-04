import 'package:studentry/auth/presentation/auth_mixin.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/auth/presentation/otp_verification_screen.dart';
import 'package:studentry/auth/presentation/password_reset_screen.dart';
import 'package:studentry/shared/data/api_request_queue.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with AuthMixin, SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  final String _selectedRole = 'student';
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
          ),
        );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    if (!mounted) return;

    final email = _emailController.text.trim();
    final password = passwordController.text;

    try {
      final response = await AuthService().signIn(email, password);
      final user = response.user;
      if (user == null) throw Exception('فشل تسجيل الدخول');

      if (!mounted) return;
      navigateAuthenticatedUser(user, this.context);
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.statusCode == 403 && e.details is Map) {
        final details = Map<String, dynamic>.from(e.details! as Map);
        if (details['code'] == 'email_verification_required') {
          final data = details['data'] is Map
              ? Map<String, dynamic>.from(details['data'] as Map)
              : const <String, dynamic>{};
          final proceed = await _showVerificationRequiredDialog();
          if (!proceed || !mounted) return;
          Navigator.push(
            this.context,
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                email: email,
                selectedRole: 'student',
                purpose: 'email_verification',
                initialResendSeconds:
                    (data['resend_after'] as num?)?.toInt() ?? 60,
              ),
            ),
          );
          return;
        }
      }
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _showVerificationRequiredDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'تأكيد البريد الإلكتروني',
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'حسابك موجود، لكنه غير مفعّل بعد. أرسلنا رمز تحقق إلى بريدك الإلكتروني. '
              'لن تتمكن من الدخول قبل إدخال الرمز.',
              textAlign: TextAlign.right,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('إدخال الرمز'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'إعادة تعيين كلمة المرور',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('أدخل بريدك الإلكتروني وسنرسل لك رمز إعادة التعيين'),
            SizedBox(height: 16.h),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'البريد الإلكتروني',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.authFieldBg,
              ),
            ),
          ],
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
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) return;
              try {
                final dispatch = await AuthService().resetPasswordForEmail(
                  email,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PasswordResetScreen(
                      email: email,
                      initialResendSeconds: dispatch.resendAfter,
                    ),
                  ),
                );
              } catch (_) {
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('فشل إرسال رمز إعادة التعيين'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF6FBFC),
      body: SafeArea(
        child: Stack(
          children: [
            buildAuthBackdrop(),
            FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final formWidth = constraints.maxWidth > 600
                        ? 430.0
                        : constraints.maxWidth * 0.90;
                    return Padding(
                      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 8.h),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: formWidth,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildHeader(),
                                SizedBox(height: 18.h),
                                _buildLoginCard(),
                                SizedBox(height: 8.h),
                                _buildSignUpLink(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
        SizedBox(height: 14.h),
        Text(
          'مرحباً بعودتك',
          style: TextStyle(
            color: AppColors.authTextDark,
            fontSize: 24.sp,
            fontWeight: FontWeight.w800,
            height: 1.3,
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 3.h),
        Text(
          'أدخل بياناتك للمتابعة',
          style: TextStyle(
            color: AppColors.authGrey,
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
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
          mainAxisSize: MainAxisSize.min,
          children: [
            buildField(
              controller: _emailController,
              hint: 'البريد الإلكتروني',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              compact: true,
            ),
            SizedBox(height: 10.h),
            buildField(
              controller: passwordController,
              hint: 'كلمة المرور',
              icon: Icons.lock_outline,
              isPassword: true,
              compact: true,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _showForgotPasswordDialog(context),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                ),
                child: Text(
                  'نسيت كلمة المرور؟',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(height: 6.h),
            _buildLoginButton(),
            SizedBox(height: 12.h),
            buildOrDivider(),
            SizedBox(height: 10.h),
            buildGoogleButton(
              () => signInWithGoogle(selectedRole: _selectedRole),
              compact: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 60.h,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textLight,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
            disabledForegroundColor: AppColors.textLight.withValues(alpha: 0.8),
            elevation: 0,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          onPressed: _isLoading ? null : () => _handleLogin(context),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: _isLoading
                ? SizedBox(
                    key: const ValueKey('loading'),
                    width: 22.w,
                    height: 22.h,
                    child: CircularProgressIndicator(
                      color: AppColors.textLight,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    key: const ValueKey('text'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login_rounded, size: 18.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'تسجيل الدخول',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Center(
      child: TextButton(
        onPressed: () => Navigator.pushNamed(context, '/register'),
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'ليس لديك حساب؟ ',
                style: TextStyle(
                  color: AppColors.authGrey,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
              TextSpan(
                text: 'إنشاء حساب',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
