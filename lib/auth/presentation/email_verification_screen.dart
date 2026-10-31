import 'auth_layout.dart';
import 'package:studentry/shared/providers/auth_provider.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  String? _email;
  bool _isVerifying = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_email == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _email = args;
      }
      if (args is Map) {
        _email = args['email'] as String?;
      }
    }
  }

  Future<void> _verifyAndProceed() async {
    setState(() => _isVerifying = true);
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    setState(() => _isVerifying = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إنشاء الحساب! فعّل بريدك الإلكتروني ثم سجل الدخول.'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'فعّل حسابك',
    subtitle: 'تم إرسال رابط التفعيل إلى ${_email ?? ""}',
    compact: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _infoCard(),
        const SizedBox(height: 20),
        _verifyButton(),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/register',
            (_) => false,
          ),
          child: const Text('إنشاء حساب جديد'),
        ),
      ],
    ),
  );

  Widget _infoCard() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'افتح بريدك الإلكتروني واضغط على رابط التفعيل',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'بعد التفعيل، ارجع إلى التطبيق واضغط على "تحقق"',
                  style: TextStyle(fontSize: 12, color: AppColors.authGrey),
                ),
                SizedBox(height: 4),
                Text(
                  'تحقق من مجلد Spam إذا لم يصلك الرابط',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.authGrey.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _verifyButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 4,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _isVerifying ? null : _verifyAndProceed,
        icon: _isVerifying
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.verified_user_outlined, size: 22),
        label: Text(
          'تحقق',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
