import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:studentry/auth/presentation/auth_layout.dart';
import 'package:studentry/shared/widgets/studentry_illustration.dart';
import 'package:studentry/student/presentation/widgets/student_welcome_card.dart';
import 'package:studentry/utils/app_theme.dart';

Widget _preview(Widget child) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.light(),
  home: Directionality(textDirection: TextDirection.rtl, child: child),
);

@Preview(
  name: 'الرئيسية — ترحيب',
  group: 'Studentry mobile',
  size: Size(390, 360),
)
@Preview(
  name: 'الرئيسية — عرض صغير',
  group: 'Studentry mobile',
  size: Size(320, 410),
)
Widget studentWelcomePreview() => _preview(
  const Scaffold(
    body: Padding(
      padding: EdgeInsets.all(16),
      child: StudentWelcomeCard(
        name: 'أحمد محمد',
        date: 'الخميس ٢٩ أكتوبر ٢٠٢٦',
      ),
    ),
  ),
);

@Preview(
  name: 'الدخول — سطح النموذج',
  group: 'Studentry mobile',
  size: Size(390, 844),
)
Widget mobileAuthLayoutPreview() => _preview(
  AuthLayout(
    title: 'مرحباً بعودتك',
    subtitle: 'دراستك، مرضاك ومواعيدك في مكان واحد.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TextField(
          decoration: InputDecoration(
            hintText: 'البريد الإلكتروني',
            prefixIcon: Icon(Icons.mail_outline),
          ),
        ),
        const SizedBox(height: 12),
        const TextField(
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'كلمة المرور',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: () {}, child: const Text('تسجيل الدخول')),
      ],
    ),
  ),
);

@Preview(name: 'رسمة السبلاش', group: 'Studentry mobile', size: Size(390, 844))
Widget mobileSplashPreview() => _preview(
  const Scaffold(
    backgroundColor: Color(0xFFE8F6F7),
    body: Center(
      child: SizedBox(
        width: 240,
        height: 240,
        child: StudentryIllustration(splash: true),
      ),
    ),
  ),
);
