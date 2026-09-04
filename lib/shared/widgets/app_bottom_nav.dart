import 'package:studentry/patients/presentation/appointments_screen.dart';
import 'package:studentry/patients/presentation/reports_screen.dart';
import 'package:studentry/shared/widgets/sync_status_indicator.dart';
import 'package:studentry/store/presentation/store_screen.dart';
import 'package:studentry/student/presentation/student_home_screen.dart';
import 'package:studentry/student/presentation/university_screen.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';

class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final int appointmentBadgeCount;
  final ValueChanged<int>? onSelected;

  const AppBottomNav({
    super.key,
    this.selectedIndex = 0,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SyncStatusIndicator(),
          SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  _item(
                    context,
                    Icons.home_rounded,
                    'الرئيسية',
                    selectedIndex == 0,
                    () => _select(context, 0, const StudentHomeScreen()),
                  ),
                  _item(
                    context,
                    Icons.calendar_month_rounded,
                    'المواعيد',
                    selectedIndex == 1,
                    () => _select(context, 1, const AppointmentsScreen()),
                    badge: appointmentBadgeCount,
                  ),
                  _item(
                    context,
                    Icons.school_rounded,
                    'جامعتي',
                    selectedIndex == 2,
                    () => _select(context, 2, const UniversityScreen()),
                  ),
                  _item(
                    context,
                    Icons.store_rounded,
                    'المتجر',
                    selectedIndex == 3,
                    () => _select(context, 3, const StoreScreen()),
                  ),
                  _item(
                    context,
                    Icons.analytics_rounded,
                    'التقارير',
                    selectedIndex == 4,
                    () => _select(context, 4, const ReportsScreen()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String label,
    bool selected,
    VoidCallback onTap, {
    int badge = 0,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          key: ValueKey('bottom-nav-$label'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(7),
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
                      size: 23,
                    ),
                  ),
                  if (badge > 0)
                    PositionedDirectional(
                      start: -6,
                      top: -3,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$badge',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? AppColors.primary : AppColors.textLightGray,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
