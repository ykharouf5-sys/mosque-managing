import 'package:studentry/patients/presentation/add_patient_screen.dart';
import 'package:studentry/patients/presentation/appointments_screen.dart';
import 'package:studentry/patients/presentation/reports_screen.dart';
import 'package:studentry/store/presentation/store_screen.dart';
import 'package:studentry/student/presentation/university_screen.dart';
import 'package:studentry/student/presentation/student_home_screen.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';

class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final bool showAddButton;
  final int appointmentBadgeCount;
  final ValueChanged<int>? onSelected;

  const AppBottomNav({
    super.key,
    this.selectedIndex = 0,
    this.showAddButton = false,
    this.appointmentBadgeCount = 0,
    this.onSelected,
  });

  void _select(BuildContext context, int index, Widget page) {
    if (onSelected != null) {
      onSelected!(index);
      return;
    }
    if (selectedIndex == index) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final partWidth = constraints.maxWidth / (showAddButton ? 6 : 5);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubic,
              height: showAddButton ? 78 : 62,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedPadding(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOutCubic,
                    padding: EdgeInsets.only(top: showAddButton ? 14 : 0),
                    child: Row(
                      children: [
                        _item(
                          context,
                          Icons.home_rounded,
                          'الرئيسية',
                          selectedIndex == 0,
                          () => _select(context, 0, const StudentHomeScreen()),
                          partWidth,
                        ),
                        _item(
                          context,
                          Icons.calendar_month_rounded,
                          'المواعيد',
                          selectedIndex == 1,
                          () => _select(context, 1, const AppointmentsScreen()),
                          partWidth,
                          badge: appointmentBadgeCount,
                        ),
                        SizedBox(width: showAddButton ? partWidth : 0),
                        _item(
                          context,
                          Icons.school_rounded,
                          'جامعتي',
                          selectedIndex == 2,
                          () => _select(context, 2, const UniversityScreen()),
                          partWidth,
                        ),
                        _item(
                          context,
                          Icons.store_rounded,
                          'المتجر',
                          selectedIndex == 3,
                          () => _select(context, 3, const StoreScreen()),
                          partWidth,
                        ),
                        _item(
                          context,
                          Icons.analytics_rounded,
                          'التقارير',
                          selectedIndex == 4,
                          () => _select(context, 4, const ReportsScreen()),
                          partWidth,
                        ),
                      ],
                    ),
                  ),
                  if (showAddButton)
                    Positioned(
                      top: -6,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddPatientScreen(),
                            ),
                          ),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryLight,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_add_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    bool selected,
    VoidCallback onTap,
    double width, {
    int badge = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textLightGray,
                    size: 24,
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    left: 4,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: selected ? AppColors.primary : AppColors.textLightGray,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
