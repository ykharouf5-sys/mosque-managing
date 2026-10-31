import 'package:studentry/utils/app_input_formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:studentry/utils/variable_colors.dart';

class PasswordResetRequest {
  const PasswordResetRequest(this.email, this.resendSeconds);
  final String email;
  final int resendSeconds;
}

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({
    super.key,
    this.initialEmail = '',
    required this.sendCode,
  });

  final String initialEmail;
  final Future<int> Function(String email) sendCode;

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail,
  );
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final email = _email.text.trim().toLowerCase();
    try {
      final seconds = await widget.sendCode(email);
      if (!mounted) return;
      Navigator.pop(context, PasswordResetRequest(email, seconds));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error =
            'تعذر إرسال الرمز. ${error.toString().replaceFirst('Exception: ', '')}';
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_sending,
    child: Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight:
              (MediaQuery.sizeOf(context).height -
                      MediaQuery.viewInsetsOf(context).bottom -
                      48)
                  .clamp(160.0, 400.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'إعادة تعيين كلمة المرور',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => Align(
                    alignment: Alignment.topCenter,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: box.maxWidth,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'سنرسل رمز تحقق من ٦ أرقام إلى بريدك لتغيير كلمة المرور.',
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                inputFormatters: AppInputFormatters.text(254),
                                textAlignVertical: TextAlignVertical.center,
                                controller: _email,
                                enabled: !_sending,
                                keyboardType: TextInputType.emailAddress,
                                textDirection: TextDirection.ltr,
                                autofillHints: const [AutofillHints.email],
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _send(),
                                validator: (value) =>
                                    RegExp(
                                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                    ).hasMatch(value?.trim() ?? '')
                                    ? null
                                    : 'أدخل بريداً إلكترونياً صحيحاً',
                                decoration: InputDecoration(
                                  labelText: 'البريد الإلكتروني',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.authFieldBg,
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _sending ? null : () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('إرسال الرمز'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<int> forgotPasswordPreviewSend(String email) async => 60;

@Preview(
  name: 'Request password reset code',
  group: 'Authentication',
  size: Size(380, 340),
)
Widget forgotPasswordDialogPreview() => const MaterialApp(
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: ForgotPasswordDialog(
      initialEmail: 'student@example.com',
      sendCode: forgotPasswordPreviewSend,
    ),
  ),
);
