import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:studentry/utils/variable_colors.dart';

class AppointmentFormOverview extends StatelessWidget {
  const AppointmentFormOverview({
    super.key,
    required this.patientName,
    required this.date,
    required this.time,
    required this.onChooseDateTime,
  });

  final String patientName;
  final DateTime date;
  final TimeOfDay time;
  final VoidCallback onChooseDateTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            patientName.isEmpty ? 'اختر المريض' : patientName,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onChooseDateTime,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.featureBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${DateFormat('EEEE، d MMMM', 'ar').format(date)} • ${time.format(context)}',
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.edit_calendar_rounded,
                    color: AppColors.textGray,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
