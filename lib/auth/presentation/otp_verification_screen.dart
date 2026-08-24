import 'dart:async';

import 'package:studentry/auth/presentation/auth_mixin.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  final String selectedRole;
  final String purpose;
  final int initialResendSeconds;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.selectedRole,
    this.purpose = 'login',
    this.initialResendSeconds = 60,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen>
    with AuthMixin {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  int _resendTimer = 60;
  bool _canResend = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer(widget.initialResendSeconds);
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    passwordController.dispose();
    super.dispose();
  }

  void _startTimer([int seconds = 60]) {
    _timer?.cancel();
    setState(() {
      _resendTimer = seconds;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendTimer > 1) {
          _resendTimer--;
        } else {
          _resendTimer = 0;
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  void _onCodeChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال رمز التحقق كاملاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await AuthService().verifyOTP(
        email: widget.email,
        token: code,
        purpose: widget.purpose,
      );

      if (response.user == null) {
        throw Exception('رمز التحقق غير صحيح');
      }

      final user = response.user!;
      if (!mounted) return;
      navigateAuthenticatedUser(user, context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    if (!_canResend || _isResending) return;
    setState(() => _isResending = true);

    try {
      final dispatch = await AuthService().sendOtp(
        widget.email,
        purpose: widget.purpose,
      );
      _startTimer(dispatch.resendAfter);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال رمز تحقق جديد إلى بريدك'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الإرسال: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: AppColors.authTextDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          buildAuthBackdrop(),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.r),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: buildAuthSurface(
                    child: Column(
                      children: [
                        _buildMailIcon(),
                        SizedBox(height: 20.h),
                        Text(
                          'تحقق من بريدك',
                          style: TextStyle(
                            fontSize: 25.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.authTextDark,
                          ),
                        ).animate().fadeIn().slideY(begin: 0.2),
                        SizedBox(height: 10.h),
                        Text(
                          'أرسلنا رمزاً من 6 أرقام إلى',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.authGrey,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 360),
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 9.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Text(
                            widget.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        SizedBox(height: 30.h),
                        _buildOtpFields(),
                        SizedBox(height: 28.h),
                        _buildVerifyButton(),
                        SizedBox(height: 16.h),
                        _buildResendSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMailIcon() {
    return Container(
      width: 80.w,
      height: 80.h,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.mark_email_unread_outlined,
        size: 40.sp,
        color: AppColors.primary,
      ),
    ).animate().fadeIn(duration: 400.ms).then().shake();
  }

  Widget _buildOtpFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxWidth < 350 ? 5.0 : 8.0;
        final fieldWidth = ((constraints.maxWidth - (gap * 5)) / 6).clamp(
          38.0,
          52.0,
        );
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (index) {
              return Padding(
                    padding: EdgeInsets.only(right: index == 5 ? 0 : gap),
                    child: SizedBox(
                      width: fieldWidth,
                      height: 58.h,
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        autofillHints: index == 0
                            ? const [AutofillHints.oneTimeCode]
                            : null,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.authTextDark,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: AppColors.authFieldBg,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(
                              color: AppColors.authFieldBorder,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide(
                              color: AppColors.authFieldBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (v) => _onCodeChanged(index, v),
                        onTapOutside: (_) {},
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: (100 * index).ms)
                  .slideY(begin: 0.3, delay: (100 * index).ms);
            }),
          ),
        );
      },
    );
  }

  Widget _buildVerifyButton() {
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
        onPressed: _isLoading ? null : _verifyOtp,
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
                  Icon(Icons.verified_user_outlined, size: 20.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'تحقق',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildResendSection() {
    return Column(
      children: [
        if (!_canResend)
          Text(
            'إعادة الإرسال بعد 0:${_resendTimer.toString().padLeft(2, '0')}',
            style: TextStyle(color: AppColors.authGrey, fontSize: 13.sp),
          ),
        SizedBox(height: 8.h),
        TextButton(
          onPressed: _canResend && !_isResending ? _resendCode : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            disabledForegroundColor: AppColors.authGrey,
          ),
          child: _isResending
              ? SizedBox(
                  width: 18.w,
                  height: 18.h,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Text(
                  'إعادة إرسال الرمز',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
        SizedBox(height: 16.h),
        TextButton(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (_) => false,
          ),
          child: Text(
            'تسجيل الدخول بكلمة مرور',
            style: TextStyle(color: AppColors.authGrey, fontSize: 13.sp),
          ),
        ),
      ],
    );
  }
}
