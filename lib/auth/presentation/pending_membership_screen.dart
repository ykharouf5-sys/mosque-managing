import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/shared/providers/auth_provider.dart';
import 'package:studentry/utils/variable_colors.dart';

class ClinicalMembershipGate extends StatelessWidget {
  final bool hasActiveMembership;
  final Widget child;

  const ClinicalMembershipGate({
    super.key,
    required this.hasActiveMembership,
    required this.child,
  });

  @override
  Widget build(BuildContext context) =>
      hasActiveMembership ? child : const PendingMembershipScreen();
}

class PendingMembershipScreen extends ConsumerStatefulWidget {
  const PendingMembershipScreen({super.key});

  @override
  ConsumerState<PendingMembershipScreen> createState() =>
      _PendingMembershipScreenState();
}

class _PendingMembershipScreenState
    extends ConsumerState<PendingMembershipScreen> {
  bool _refreshing = false;
  bool _signingOut = false;

  Future<void> _refreshMembership() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final user = await AuthService().refreshCurrentUser();
      ref.read(authProvider.notifier).setAuthUser(user);
      if (!mounted) return;
      if (!user.hasActiveClinicalMembership) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ما زال الحساب بانتظار ربطه بعيادة.')),
        );
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        _landingRoute(user),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر التحقق الآن. تأكد من الاتصال وحاول مجددًا.'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  String _landingRoute(AuthUser user) {
    switch (user.role) {
      case 'admin':
      case 'sales_manager':
        return '/sales-dashboard';
      case 'student_manager':
        return '/student-admin';
      case 'warehouse_manager':
        return '/warehouse-dashboard';
      case 'student':
        return user.profileCompleted ? '/student-home' : '/student-profile';
      default:
        return '/student-home';
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await AuthService().signOut();
      ref.read(authProvider.notifier).clearAuth();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final email = AuthService().email;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.divider),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_outlined,
                          color: AppColors.primary,
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'حسابك بانتظار التفعيل',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'تم توثيق حسابك بنجاح. يجب أن يربطه مدير العيادة قبل الوصول إلى المرضى والمواعيد والبيانات السريرية.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                      if (email != null && email.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          email,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.pending.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              color: AppColors.pending,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                auth.membershipStatus == 'pending'
                                    ? 'بانتظار ربط الحساب بعيادة'
                                    : 'الوصول السريري غير مفعل',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _refreshing ? null : _refreshMembership,
                          icon: _refreshing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                          label: Text(
                            _refreshing
                                ? 'جارٍ التحقق...'
                                : 'التحقق من حالة الحساب',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _signingOut ? null : _signOut,
                        icon: const Icon(Icons.logout_rounded),
                        label: Text(
                          _signingOut ? 'جارٍ تسجيل الخروج...' : 'تسجيل الخروج',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
