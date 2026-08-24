import 'package:studentry/shared/providers/auth_provider.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
    setState(() => _isVerifying = false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إنشاء الحساب! فعّل بريدك الإلكتروني ثم سجل الدخول.'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 28.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _mailIcon(),
                SizedBox(height: 32.h),
                Text(
                  'فعّل حسابك',
                  style: TextStyle(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ).animate().fadeIn().slideY(begin: 0.2),
                SizedBox(height: 12.h),
                Text(
                  'تم إرسال رابط التفعيل إلى',
                  style: TextStyle(fontSize: 14.sp, color: AppColors.authGrey),
                ),
                SizedBox(height: 6.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 10.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _email ?? '',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                SizedBox(height: 24.h),
                _infoCard(),
                SizedBox(height: 32.h),
                _verifyButton(),
                SizedBox(height: 16.h),
                TextButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/register',
                    (_) => false,
                  ),
                  child: Text(
                    'إنشاء حساب جديد',
                    style: TextStyle(
                      color: AppColors.authGrey,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mailIcon() {
    return Container(
      width: 100.w,
      height: 100.h,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.mark_email_read_outlined,
        size: 50.sp,
        color: AppColors.primary,
      ),
    ).animate().fadeIn(duration: 600.ms).then().shake();
  }

  Widget _infoCard() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 20),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'افتح بريدك الإلكتروني واضغط على رابط التفعيل',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'بعد التفعيل، ارجع إلى التطبيق واضغط على "تحقق"',
                  style: TextStyle(fontSize: 12.sp, color: AppColors.authGrey),
                ),
                SizedBox(height: 4.h),
                Text(
                  'تحقق من مجلد Spam إذا لم يصلك الرابط',
                  style: TextStyle(
                    fontSize: 12.sp,
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
      height: 54.h,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _isVerifying ? null : _verifyAndProceed,
        icon: _isVerifying
            ? SizedBox(
                width: 20.w,
                height: 20.h,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.verified_user_outlined, size: 22),
        label: Text(
          'تحقق',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
