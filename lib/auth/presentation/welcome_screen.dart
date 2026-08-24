import 'package:studentry/auth/presentation/otp_verification_screen.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
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
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();

    final exists = await AuthService().emailExists(email);

    if (!mounted) return;

    if (exists) {
      _showAccountExistsDialog(email);
      return;
    }

    Navigator.pushNamed(context, '/register');
  }

  void _showAccountExistsDialog(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'حساب موجود بالفعل',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 48.sp, color: Colors.orange),
            SizedBox(height: 16.h),
            Text(
              'هذا البريد الإلكتروني مسجل لدينا بالفعل',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: AppColors.authGrey),
            ),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                email,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'اختر طريقة تسجيل الدخول:',
              style: TextStyle(fontSize: 13.sp, color: AppColors.authGrey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/login');
            },
            child: const Text('كلمة مرور'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _sendOtpAndNavigate(email);
            },
            child: const Text('رمز تحقق'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendOtpAndNavigate(String email) async {
    setState(() => _isLoading = true);
    try {
      final dispatch = await AuthService().sendOtp(email, purpose: 'login');
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            email: email,
            selectedRole: _selectedRole,
            purpose: 'login',
            initialResendSeconds: dispatch.resendAfter,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل إرسال رمز التحقق: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      await AuthService().signInWithGoogle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل تسجيل الدخول بـ Google: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.authBackground,
      body: SafeArea(
        child: Stack(
          children: [
            _buildBackgroundLogo(),
            FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 600;
                    final hPad = isWide ? constraints.maxWidth * 0.15 : 24.w;
                    return SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            SizedBox(height: constraints.maxHeight * 0.04),
                            _buildHeader(),
                            SizedBox(height: constraints.maxHeight * 0.02),
                            _buildSubtitle(),
                            SizedBox(height: 20.h),
                            _buildEmailField(),
                            SizedBox(height: 24.h),
                            _buildContinueButton(),
                            SizedBox(height: 16.h),
                            _buildDivider(),
                            SizedBox(height: 16.h),
                            _buildGoogleButton(),
                            SizedBox(height: 20.h),
                            _buildLoginLink(),
                            SizedBox(height: 24.h),
                          ],
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

  Widget _buildBackgroundLogo() {
    return Positioned.fill(
      child: Center(
        child: Opacity(
          opacity: 0.06,
          child: Image.asset(
            'assets/image/logo.png',
            width: 1.8.sw,
            height: 1.8.sw,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Image.asset(
          'assets/image/logo.png',
          width: 70.w,
          height: 70.h,
          fit: BoxFit.contain,
        ),
        SizedBox(height: 12.h),
        Text(
          'Studentry',
          style: TextStyle(
            color: AppColors.authTextDark,
            fontSize: 24.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'منصة الطلاب',
          style: TextStyle(
            color: AppColors.authGrey,
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitle() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Text(
        'أدخل بريدك الإلكتروني للمتابعة',
        style: TextStyle(
          color: AppColors.authGrey,
          fontSize: 14.sp,
          fontWeight: FontWeight.w400,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 16.sp,
        color: AppColors.authTextDark,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'example@email.com',
        hintTextDirection: TextDirection.ltr,
        hintStyle: TextStyle(
          color: AppColors.authGrey.withValues(alpha: 0.6),
          fontSize: 14.sp,
        ),
        prefixIcon: Icon(
          Icons.email_outlined,
          color: AppColors.primary,
          size: 20.sp,
        ),
        filled: true,
        fillColor: AppColors.authFieldBg,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.authFieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.authFieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) return 'البريد الإلكتروني مطلوب';
        if (!val.contains('@') || !val.contains('.')) {
          return 'بريد إلكتروني غير صالح';
        }
        return null;
      },
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textLight,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          shadowColor: AppColors.primary.withValues(alpha: 0.25),
        ),
        onPressed: _isLoading ? null : _handleContinue,
        child: _isLoading
            ? SizedBox(
                width: 22.w,
                height: 22.h,
                child: CircularProgressIndicator(
                  color: AppColors.textLight,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'متابعة',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(Icons.arrow_forward, size: 18.sp),
                ],
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: AppColors.authFieldBorder, thickness: 1),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Text(
            'أو',
            style: TextStyle(
              color: AppColors.authGrey,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: AppColors.authFieldBorder, thickness: 1),
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: AppColors.authFieldBorder, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: EdgeInsets.zero,
          elevation: 0,
        ),
        onPressed: _handleGoogleSignIn,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'متابعة باستخدام ',
              style: TextStyle(
                color: AppColors.authGrey,
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              'Google',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.authTextDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: TextButton(
        onPressed: () => Navigator.pushNamed(context, '/login'),
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'لديك حساب بالفعل؟ ',
                style: TextStyle(
                  color: AppColors.authGrey,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
              TextSpan(
                text: 'تسجيل الدخول',
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
