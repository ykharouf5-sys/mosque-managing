import 'package:dentalcare/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFC),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFEAF8FA), Color(0xFFF8FCFD), Colors.white],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth > 600
                  ? constraints.maxWidth * 0.88
                  : constraints.maxWidth * 0.90;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: contentWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildBrandHeader(),
                          SizedBox(height: 14.h),
                          _buildLiquidGlassHero(),
                          SizedBox(height: 18.h),
                          _buildMessage(),
                          SizedBox(height: 18.h),
                          _buildFeaturePills(),
                          SizedBox(height: 24.h),
                          _buildActions(context),
                          SizedBox(height: 10.h),
                          _buildVersionText(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 54.r,
          height: 54.r,
          padding: EdgeInsets.all(7.r),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(17.r),
            border: Border.all(color: Colors.white),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Image.asset('assets/image/logo.png', fit: BoxFit.contain),
        ),
        SizedBox(width: 11.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Studentry',
              style: TextStyle(
                color: AppColors.authTextDark,
                fontSize: 23.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              'منصة طالب طب الأسنان',
              style: TextStyle(
                color: AppColors.authGrey,
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 450.ms).slideY(begin: -0.08);
  }

  Widget _buildLiquidGlassHero() {
    return Container(
          width: double.infinity,
          height: 230.h,
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(32.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.11),
                blurRadius: 30,
                offset: const Offset(0, 13),
              ),
            ],
          ),
          child: Image.asset(
            'assets/image/onboarding_liquid_glass.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        )
        .animate()
        .fadeIn(duration: 550.ms, delay: 100.ms)
        .scale(begin: const Offset(0.96, 0.96));
  }

  Widget _buildMessage() {
    return Column(
      children: [
        Text(
          'دراستك وعيادتك، أبسط من أي وقت',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.authTextDark,
            fontSize: 29.sp,
            fontWeight: FontWeight.w800,
            height: 1.35,
          ),
        ),
        SizedBox(height: 7.h),
        Text(
          'كل ما تحتاجه في رحلتك الجامعية والسريرية، منظّم في منصة واحدة صُممت خصيصاً لطلاب طب الأسنان.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.authGrey,
            fontSize: 13.5.sp,
            fontWeight: FontWeight.w400,
            height: 1.55,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 450.ms, delay: 300.ms).slideY(begin: 0.08);
  }

  Widget _buildFeaturePills() {
    return Row(
      children: [
        Expanded(child: _buildFeature(Icons.calendar_month_rounded, 'برنامجي')),
        SizedBox(width: 8.w),
        Expanded(child: _buildFeature(Icons.menu_book_rounded, 'دروسي')),
        SizedBox(width: 8.w),
        Expanded(child: _buildFeature(Icons.medical_services_rounded, 'مرضاي')),
      ],
    ).animate().fadeIn(duration: 450.ms, delay: 430.ms);
  }

  Widget _buildFeature(IconData icon, String label) {
    return Container(
      height: 48.h,
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F9),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 18.sp),
          SizedBox(width: 5.w),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.authTextDark,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 60.h,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF08788B)],
              ),
              borderRadius: BorderRadius.circular(19.r),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(19.r),
                onTap: () => Navigator.pushNamed(context, '/register'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'ابدأ الآن',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 21.sp,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 10.h),
        SizedBox(
          width: double.infinity,
          height: 58.h,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              backgroundColor: Colors.white.withValues(alpha: 0.88),
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.24),
                width: 1.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(19.r),
              ),
            ),
            onPressed: () => Navigator.pushNamed(context, '/login'),
            child: Text(
              'لدي حساب بالفعل',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 450.ms, delay: 550.ms).slideY(begin: 0.08);
  }

  Widget _buildVersionText() {
    return Text(
      'نسخة ١.٠',
      style: TextStyle(
        color: AppColors.authGrey.withValues(alpha: 0.7),
        fontSize: 10.5.sp,
        fontWeight: FontWeight.w400,
      ),
    ).animate().fadeIn(duration: 350.ms, delay: 700.ms);
  }
}
