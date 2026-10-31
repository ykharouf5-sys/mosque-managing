import 'package:studentry/patients/presentation/appointments_screen.dart';
import 'package:studentry/patients/presentation/reports_screen.dart';
import 'package:studentry/shared/widgets/sync_status_indicator.dart';
import 'package:studentry/store/presentation/store_screen.dart';
import 'package:studentry/student/presentation/student_home_screen.dart';
import 'package:studentry/student/presentation/university_screen.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:studentry/student/presentation/widgets/home_dashboard_widgets.dart';

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
    final palette = HomePalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: palette.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -3),
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
              height:
                  66 +
                  (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0, 2) *
                      18,
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
                    Icons.bar_chart_rounded,
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
    final palette = HomePalette.of(context);
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
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: .10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      icon,
                      color: selected
                          ? (palette.dark
                                ? const Color(0xFF85D6DF)
                                : AppColors.primary)
                          : palette.muted,
                      size: 25,
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
                  fontSize: 10.5,
                  color: selected
                      ? (palette.dark
                            ? const Color(0xFF85D6DF)
                            : HomePalette.brandInk)
                      : palette.muted,
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
