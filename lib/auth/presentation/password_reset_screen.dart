import 'package:studentry/auth/presentation/auth_layout.dart';
import 'package:studentry/utils/app_input_formatters.dart';
import 'dart:async';

import 'package:studentry/shared/data/auth_service.dart';
import 'package:flutter/material.dart';

class PasswordResetScreen extends StatefulWidget {
  final String email;
  final int initialResendSeconds;

  const PasswordResetScreen({
    super.key,
    required this.email,
    this.initialResendSeconds = 60,
  });

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  Timer? _timer;
  bool _loading = false;
  bool _resending = false;
  bool _obscure = true;
  int _seconds = 60;

  @override
  void initState() {
    super.initState();
    _startTimer(widget.initialResendSeconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() => _seconds = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _seconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _seconds = 0);
        return;
      }
      setState(() => _seconds--);
    });
  }

  Future<void> _reset() async {
    if (!(_formKey.currentState?.validate() ?? false) || _loading) return;
    setState(() => _loading = true);
    try {
      await AuthService().resetPassword(
        email: widget.email,
        code: _codeController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تغيير كلمة المرور بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_seconds > 0 || _resending) return;
    setState(() => _resending = true);
    try {
      final dispatch = await AuthService().resetPasswordForEmail(widget.email);
      if (!mounted) return;
      _startTimer(dispatch.resendAfter);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال رمز جديد'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'كلمة مرور جديدة',
    subtitle: 'أدخل الرمز المرسل إلى ${widget.email} ثم اختر كلمة مرور جديدة.',
    compact: true,
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _codeController,
            enabled: !_loading,
            textDirection: TextDirection.ltr,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: AppInputFormatters.integer(digits: 6),
            decoration: const InputDecoration(
              labelText: 'رمز التحقق',
              counterText: '',
            ),
            validator: (value) =>
                value?.length == 6 ? null : 'أدخل الرمز المكوّن من 6 أرقام',
          ),
          SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            enabled: !_loading,
            autofillHints: const [AutofillHints.newPassword],
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'كلمة المرور الجديدة',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.length < 8) {
                return 'ثمانية أحرف على الأقل';
              }
              if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
                  !RegExp(r'\d').hasMatch(value)) {
                return 'استخدم أحرفاً وأرقاماً';
              }
              return null;
            },
          ),
          SizedBox(height: 14),
          TextFormField(
            controller: _confirmationController,
            enabled: !_loading,
            autofillHints: const [AutofillHints.newPassword],
            obscureText: true,
            decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور'),
            validator: (value) => value == _passwordController.text
                ? null
                : 'كلمتا المرور غير متطابقتين',
          ),
          SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _reset,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('تغيير كلمة المرور'),
            ),
          ),
          SizedBox(height: 12),
          TextButton(
            onPressed: _seconds == 0 && !_resending && !_loading
                ? _resend
                : null,
            child: Text(
              _seconds > 0
                  ? 'إعادة الإرسال بعد $_seconds ثانية'
                  : 'إعادة إرسال الرمز',
            ),
          ),
        ],
      ),
    ),
  );
}
