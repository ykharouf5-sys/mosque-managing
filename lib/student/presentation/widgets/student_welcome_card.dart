import 'package:flutter/material.dart';
import 'package:studentry/shared/widgets/studentry_illustration.dart';
import 'package:studentry/utils/variable_colors.dart';

class StudentWelcomeCard extends StatelessWidget {
  const StudentWelcomeCard({super.key, required this.name, required this.date});
  final String name;
  final String date;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xFFE8F6F7),
      borderRadius: BorderRadius.circular(28),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(16) > 21;
        final text = Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'أهلاً بعودتك',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'معك من أول محاضرة\nلآخر موعد',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                date,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
        return stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  text,
                  const SizedBox(height: 150, child: StudentryIllustration()),
                ],
              )
            : Row(
                children: [
                  Expanded(flex: 6, child: text),
                  const Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: 190,
                      child: StudentryIllustration(),
                    ),
                  ),
                ],
              );
      },
    ),
  );
}
