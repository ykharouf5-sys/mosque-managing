import 'package:studentry/shared/providers/auth_provider.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/shared/widgets/main_navigation_screen.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class User {
  final DateTime? emailConfirmedAt;
  User({this.emailConfirmedAt});
}

class AuthField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final bool isConfirm;
  final TextInputType keyboardType;
  final TextEditingController? passwordController;
  final bool compact;
  final bool roomy;

  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.isConfirm = false,
    this.keyboardType = TextInputType.text,
    this.passwordController,
    this.compact = false,
    this.roomy = false,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField>
    with SingleTickerProviderStateMixin {
  bool _obscure = true;
  bool _hasFocus = false;
  late final AnimationController _focusController;
  late final Animation<double> _focusAnim;

  @override
  void initState() {
    super.initState();
    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _focusAnim = CurvedAnimation(
      parent: _focusController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _focusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (focused) {
        setState(() => _hasFocus = focused);
        if (focused) {
          _focusController.forward();
        } else {
          _focusController.reverse();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: (_hasFocus ? AppColors.primary : Colors.black).withValues(
                alpha: _hasFocus ? 0.12 : 0.035,
              ),
              blurRadius: _hasFocus ? 14 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextFormField(
          controller: widget.controller,
          obscureText: widget.isPassword ? _obscure : false,
          keyboardType: widget.keyboardType,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: (widget.roomy ? 17.5 : (widget.compact ? 16 : 15)).sp,
            color: AppColors.authTextDark,
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintTextDirection: TextDirection.rtl,
            hintStyle: TextStyle(
              color: AppColors.authGrey.withValues(alpha: 0.7),
              fontSize: (widget.roomy ? 16.5 : (widget.compact ? 15 : 14)).sp,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: EdgeInsets.all((widget.compact ? 7 : 10).r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: (_hasFocus ? AppColors.primary : AppColors.authGrey)
                      .withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: AnimatedBuilder(
                  animation: _focusAnim,
                  builder: (context, child) => Icon(
                    widget.icon,
                    color: Color.lerp(
                      AppColors.authGrey,
                      AppColors.primary,
                      _focusAnim.value,
                    ),
                    size: 20.sp,
                  ),
                ),
              ),
            ),
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.authGrey,
                      size: 20.sp,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
            isDense: widget.compact,
            prefixIconConstraints: widget.compact
                ? BoxConstraints(
                    minWidth: (widget.roomy ? 58 : 52).w,
                    minHeight: (widget.roomy ? 58 : 52).h,
                  )
                : null,
            suffixIconConstraints: widget.compact
                ? BoxConstraints(
                    minWidth: (widget.roomy ? 58 : 52).w,
                    minHeight: (widget.roomy ? 58 : 52).h,
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: (widget.roomy ? 19 : 16).h,
            ),
            border: _fieldBorder(AppColors.authFieldBorder, 1),
            enabledBorder: _fieldBorder(AppColors.authFieldBorder, 1),
            focusedBorder: _fieldBorder(AppColors.primary, 1.6),
            errorBorder: _fieldBorder(AppColors.danger, 1.2),
            focusedErrorBorder: _fieldBorder(AppColors.danger, 1.6),
            errorStyle: TextStyle(
              color: AppColors.danger,
              fontSize: 11.sp,
              height: 1.2,
            ),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) return 'هذا الحقل مطلوب';
            if (widget.keyboardType == TextInputType.emailAddress &&
                !val.contains('@')) {
              return 'بريد إلكتروني غير صالح';
            }
            if (widget.isConfirm &&
                widget.passwordController != null &&
                val != widget.passwordController!.text) {
              return 'كلمات المرور غير متطابقة';
            }
            return null;
          },
        ),
      ),
    );
  }

  OutlineInputBorder _fieldBorder(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// Navigation target after successful sign-in based on role
enum AuthNavigationTarget {
  salesDashboard,
  studentAdmin,
  warehouseDashboard,
  studentHome,
  emailVerification,
}

mixin AuthMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final TextEditingController passwordController = TextEditingController();

  Widget buildLogo() {
    return Positioned.fill(
      child: Center(
        child: Opacity(
          opacity: 0.08,
          child: Image.asset(
            'assets/image/logo.png',
            width: 1.8.sw,
            height: 1.8.sw,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget buildAuthBackdrop({
    String assetPath = 'assets/image/auth_login_liquid_glass.png',
    AlignmentGeometry alignment = Alignment.topCenter,
    double imageOpacity = 0.34,
  }) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFF0FAFB), Color(0xFFF8FCFD), Colors.white],
          ),
        ),
        child: Opacity(
          opacity: imageOpacity,
          child: Image.asset(
            assetPath,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.contain,
            alignment: alignment,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }

  Widget buildAuthSurface({required Widget child}) => Container(
    padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 24.h),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(28.r),
      border: Border.all(color: Colors.white),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.1),
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: child,
  );

  Widget buildLogoSmall({double size = 70}) {
    return Image.asset(
      'assets/image/logo.png',
      width: size.w,
      height: size.h,
      fit: BoxFit.contain,
    );
  }

  Widget buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isConfirm = false,
    bool compact = false,
    bool roomy = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return AuthField(
      controller: controller,
      hint: hint,
      icon: icon,
      isPassword: isPassword,
      isConfirm: isConfirm,
      keyboardType: keyboardType,
      passwordController: isConfirm ? passwordController : null,
      compact: compact,
      roomy: roomy,
    );
  }

  Widget buildGoogleButton(VoidCallback onTap, {bool compact = false}) {
    return SizedBox(
      width: double.infinity,
      height: (compact ? 58 : 60).h,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFF8FBFC),
          side: BorderSide(color: AppColors.authFieldBorder, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          padding: EdgeInsets.zero,
          elevation: 0,
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30.r,
              height: 30.r,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.authFieldBorder),
              ),
              child: const Center(
                child: Text(
                  'G',
                  style: TextStyle(
                    color: Color(0xFF4285F4),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SizedBox(width: 10.w),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'متابعة باستخدام',
                      style: TextStyle(
                        color: AppColors.authGrey,
                        fontSize: (compact ? 12.5 : 14).sp,
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Google',
                      style: TextStyle(
                        fontSize: (compact ? 15 : 17).sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.authTextDark,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildOrDivider() {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: AppColors.authFieldBorder, thickness: 1),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Text(
            'أو',
            style: TextStyle(
              color: AppColors.authGrey,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: AppColors.authFieldBorder, thickness: 1),
        ),
      ],
    );
  }

  void navigateByRoleSync(String role, BuildContext context) {
    switch (role) {
      case 'admin':
      case 'sales_manager':
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/sales-dashboard',
          (_) => false,
        );
        return;
      case 'student_manager':
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/student-admin',
          (_) => false,
        );
        return;
      case 'warehouse_manager':
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/warehouse-dashboard',
          (_) => false,
        );
        return;
      default:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (_) => false,
        );
    }
  }

  /// توجيه المستخدم بعد تسجيل الدخول بناءً على دوره
  Future<void> navigateByRole({
    required String uid,
    required String? role,
    required User authUser,
    String? selectedRole,
  }) async {
    final roleToUse = role ?? selectedRole;

    Future<void> goStudent() async {
      if (authUser.emailConfirmedAt == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('فعّل بريدك الإلكتروني أولاً'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }
      ref.read(authProvider.notifier).setAuth(uid, 'student');
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (_) => false,
      );
    }

    switch (roleToUse) {
      case 'admin':
      case 'sales_manager':
        ref.read(authProvider.notifier).setAuth(uid, roleToUse!);
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/sales-dashboard',
          (_) => false,
        );
        return;

      case 'student_manager':
        ref.read(authProvider.notifier).setAuth(uid, 'student_manager');
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/student-admin',
          (_) => false,
        );
        return;

      case 'warehouse_manager':
        ref.read(authProvider.notifier).setAuth(uid, 'warehouse_manager');
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/warehouse-dashboard',
          (_) => false,
        );
        return;

      default:
        await goStudent();
    }
  }

  Future<void> signInWithGoogle({String? selectedRole}) async {
    try {
      await AuthService().signInWithGoogle();
    } catch (e) {
      if (!mounted) return;
      String msg;
      final err = e.toString();
      if (err.contains('account-exists-with-different-credential')) {
        msg = 'هذا البريد مسجل بكلمة مرور مسبقاً';
      } else if (err.contains('network_error') ||
          err.contains('network-request-failed')) {
        msg = 'تحقق من اتصال الإنترنت وحاول مجدداً';
      } else if (err.contains('ApiException: 10') ||
          err.contains('DEVELOPER_ERROR')) {
        msg = 'خطأ في إعدادات التطبيق. تأكد من إعداد Google Sign-In في Laravel';
      } else {
        msg = 'فشل تسجيل الدخول بـ Google';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
