import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:studentry/utils/variable_colors.dart';
import 'package:table_calendar/table_calendar.dart';

class AppointmentDateTimeSelection {
  const AppointmentDateTimeSelection(this.date, this.time);

  final DateTime date;
  final TimeOfDay time;

  DateTime get dateTime =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

Future<AppointmentDateTimeSelection?> showAppointmentDateTimePicker({
  required BuildContext context,
  required DateTime initialDate,
  required TimeOfDay initialTime,
}) {
  var selectedDate = initialDate;
  var selectedTime = initialTime;
  var weekStart = initialDate.subtract(Duration(days: initialDate.weekday % 7));
  const dayNames = ['أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];

  return showDialog<AppointmentDateTimeSelection>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'اختر الموعد',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Divider(
                height: 1,
                color: AppColors.divider.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.chevron_right,
                      color: AppColors.primary,
                    ),
                    onPressed: () => setDialogState(() {
                      weekStart = weekStart.subtract(const Duration(days: 7));
                      selectedDate = weekStart;
                    }),
                  ),
                  Flexible(
                    child: Text(
                      DateFormat('MMMM yyyy', 'ar').format(weekStart),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.chevron_left,
                      color: AppColors.primary,
                    ),
                    onPressed: () => setDialogState(() {
                      weekStart = weekStart.add(const Duration(days: 7));
                      selectedDate = weekStart;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: List.generate(7, (index) {
                  final day = weekStart.add(Duration(days: index));
                  final isSelected = isSameDay(selectedDate, day);
                  final isToday = isSameDay(DateTime.now(), day);
                  return Expanded(
                    child: InkWell(
                      onTap: () => setDialogState(() => selectedDate = day),
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              dayNames[index],
                              style: TextStyle(
                                fontSize: 9,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textGray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : isToday
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : null,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  const Text(
                    'الوقت',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (time != null) {
                          setDialogState(() => selectedTime = time);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(selectedTime.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            onPressed: () => Navigator.pop(
              dialogContext,
              AppointmentDateTimeSelection(selectedDate, selectedTime),
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('تأكيد الموعد'),
          ),
        ],
      ),
    ),
  );
}
