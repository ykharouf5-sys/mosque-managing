import 'package:studentry/auth/presentation/auth_layout.dart';
import 'package:studentry/utils/app_input_formatters.dart';
import 'dart:async';

import 'package:studentry/auth/presentation/auth_mixin.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  Widget build(BuildContext context) => AuthLayout(
    title: 'تحقق من بريدك',
    subtitle: 'أدخل رمز التحقق المرسل إلى بريدك الإلكتروني.',
    compact: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.authFieldBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            widget.email,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        const SizedBox(height: 24),
        _buildOtpFields(),
        const SizedBox(height: 24),
        _buildVerifyButton(),
        const SizedBox(height: 12),
        _buildResendSection(),
      ],
    ),
  );

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
                      height: 58,
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        keyboardType: TextInputType.number,
                        inputFormatters: AppInputFormatters.integer(digits: 1),
                        autofillHints: index == 0
                            ? const [AutofillHints.oneTimeCode]
                            : null,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: TextStyle(
                          fontSize: 22,
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
        onPressed: _isLoading ? null : _verifyOtp,
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
                  Icon(Icons.verified_user_outlined, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'تحقق',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
            style: TextStyle(color: AppColors.authGrey, fontSize: 13),
          ),
        SizedBox(height: 8),
        TextButton(
          onPressed: _canResend && !_isResending ? _resendCode : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryDark,
            disabledForegroundColor: AppColors.authGrey,
          ),
          child: _isResending
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Text(
                  'إعادة إرسال الرمز',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
        ),
        SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (_) => false,
          ),
          child: Text(
            'تسجيل الدخول بكلمة مرور',
            style: TextStyle(color: AppColors.authGrey, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
