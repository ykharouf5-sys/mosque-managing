import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studentry/auth/presentation/auth_layout.dart';
import 'package:studentry/utils/variable_colors.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AuthLayout(
    showBack: false,
    title: 'معك من أول محاضرة لآخر موعد',
    subtitle: 'نظّم دراستك وملفات مرضاك، وتابع مواعيدك وطلباتك من مكان واحد.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            _Feature(icon: Icons.calendar_month_outlined, label: 'مواعيدك'),
            _Feature(icon: Icons.menu_book_outlined, label: 'دراستك'),
            _Feature(icon: Icons.medical_services_outlined, label: 'مرضاك'),
            _Feature(icon: Icons.storefront_outlined, label: 'متجرك'),
          ],
        ),
        const SizedBox(height: 28),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
          onPressed: () => Navigator.pushNamed(context, '/register'),
          child: const Text('إنشاء حساب'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
          ),
          onPressed: () => Navigator.pushNamed(context, '/login'),
          child: const Text('لدي حساب — تسجيل الدخول'),
        ),
      ],
    ),
  );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F6F7),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 19, color: AppColors.primary),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textDark,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
