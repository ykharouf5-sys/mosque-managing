import 'package:studentry/utils/app_input_formatters.dart';
import 'package:studentry/auth/presentation/auth_layout.dart';
import 'package:studentry/auth/presentation/otp_verification_screen.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/shared/data/google_auth_failure.dart';
import 'package:studentry/auth/presentation/auth_navigation.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  bool _googleSignInPending = false;
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
            Icon(Icons.info_outline, size: 48, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'هذا البريد الإلكتروني مسجل لدينا بالفعل',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.authGrey),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            SizedBox(height: 12),
            Text(
              'اختر طريقة تسجيل الدخول:',
              style: TextStyle(fontSize: 13, color: AppColors.authGrey),
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
              foregroundColor: AppColors.onPrimary,
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
    if (_googleSignInPending || !mounted) return;
    setState(() => _googleSignInPending = true);
    try {
      await AuthService().signInWithGoogle();
      final user = AuthService().currentUser;
      if (!mounted) return;
      if (user == null) {
        throw StateError('Authenticated Google user is missing');
      }
      finishAuthentication(user, context, ref);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(googleSignInFailureMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _googleSignInPending = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'أهلاً بك في Studentry',
    subtitle: 'أدخل بريدك الإلكتروني للمتابعة.',
    footer: _buildLoginLink(),
    child: FadeTransition(
      opacity: MediaQuery.disableAnimationsOf(context)
          ? const AlwaysStoppedAnimation(1)
          : _fadeAnim,
      child: SlideTransition(
        position: MediaQuery.disableAnimationsOf(context)
            ? const AlwaysStoppedAnimation(Offset.zero)
            : _slideAnim,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildEmailField(),
              const SizedBox(height: 20),
              _buildContinueButton(),
              const SizedBox(height: 16),
              _buildDivider(),
              const SizedBox(height: 16),
              _buildGoogleButton(),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildEmailField() {
    return TextFormField(
      inputFormatters: AppInputFormatters.text(254),
      textAlignVertical: TextAlignVertical.center,
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 16,
        color: AppColors.authTextDark,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'example@email.com',
        hintTextDirection: TextDirection.ltr,
        hintStyle: TextStyle(
          color: AppColors.authGrey.withValues(alpha: 0.6),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          Icons.email_outlined,
          color: AppColors.primary,
          size: 20,
        ),
        filled: true,
        fillColor: AppColors.authFieldBg,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          shadowColor: AppColors.primary.withValues(alpha: 0.25),
        ),
        onPressed: _isLoading ? null : _handleContinue,
        child: _isLoading
            ? SizedBox(
                width: 22,
                height: 22,
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18),
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
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'أو',
            style: TextStyle(
              color: AppColors.authGrey,
              fontSize: 13,
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
      height: 52,
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
        onPressed: _googleSignInPending ? null : _handleGoogleSignIn,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'متابعة باستخدام ',
              style: TextStyle(
                color: AppColors.authGrey,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            Text(
              'Google',
              style: TextStyle(
                fontSize: 17,
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
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'لديك حساب بالفعل؟ ',
                style: TextStyle(
                  color: AppColors.authGrey,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              TextSpan(
                text: 'تسجيل الدخول',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
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
