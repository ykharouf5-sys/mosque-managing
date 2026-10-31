import 'package:studentry/auth/presentation/auth_layout.dart';
import 'package:studentry/auth/presentation/auth_mixin.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/auth/presentation/otp_verification_screen.dart';
import 'package:studentry/auth/presentation/password_reset_screen.dart';
import 'package:studentry/auth/presentation/forgot_password_dialog.dart';
import 'package:studentry/shared/data/api_request_queue.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    final request = await showDialog<PasswordResetRequest>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ForgotPasswordDialog(
        initialEmail: _emailController.text.trim(),
        sendCode: (email) async =>
            (await AuthService().resetPasswordForEmail(email)).resendAfter,
      ),
    );
    if (!mounted || !context.mounted || request == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PasswordResetScreen(
          email: request.email,
          initialResendSeconds: request.resendSeconds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'مرحباً بعودتك',
    subtitle: 'دراستك، مرضاك ومواعيدك في مكان واحد.',
    footer: _buildSignUpLink(),
    child: FadeTransition(
      opacity: MediaQuery.disableAnimationsOf(context)
          ? const AlwaysStoppedAnimation(1)
          : _fadeAnim,
      child: SlideTransition(
        position: MediaQuery.disableAnimationsOf(context)
            ? const AlwaysStoppedAnimation(Offset.zero)
            : _slideAnim,
        child: _buildLoginCard(),
      ),
    ),
  );

  Widget _buildLoginCard() {
    return Form(
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
          SizedBox(height: 10),
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
                padding: EdgeInsets.symmetric(horizontal: 4),
              ),
              child: Text(
                'نسيت كلمة المرور؟',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(height: 6),
          _buildLoginButton(),
          SizedBox(height: 12),
          if (MediaQuery.viewInsetsOf(context).bottom == 0) ...[
            buildOrDivider(),
            SizedBox(height: 10),
            buildGoogleButton(
              () => signInWithGoogle(selectedRole: _selectedRole),
              compact: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
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
            foregroundColor: AppColors.onPrimary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
            disabledForegroundColor: AppColors.textLight.withValues(alpha: 0.8),
            elevation: 0,
            padding: EdgeInsets.symmetric(horizontal: 16),
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
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: AppColors.textLight,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    key: const ValueKey('text'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'تسجيل الدخول',
                        style: TextStyle(
                          fontSize: 15,
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
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              TextSpan(
                text: 'إنشاء حساب',
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
