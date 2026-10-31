import 'package:flutter/material.dart';

/// Keeps the existing persisted HH:mm - HH:mm representation.
/// Blank values remain allowed and no schedule is saved by this widget.
class LectureTimeField extends StatefulWidget {
  const LectureTimeField({
    super.key,
    required this.controller,
    this.allowClear = true,
  });
  final TextEditingController controller;
  final bool allowClear;

  @override
  State<LectureTimeField> createState() => _LectureTimeFieldState();
}

class _LectureTimeFieldState extends State<LectureTimeField> {
  bool _choosing = false;

  TimeOfDay? _existing(int index) {
    final matches = RegExp(
      r'(\d{1,2}):(\d{2})',
    ).allMatches(widget.controller.text).toList();
    if (index >= matches.length) return null;
    final hour = int.parse(matches[index][1]!);
    final minute = int.parse(matches[index][2]!);
    return hour < 24 && minute < 60
        ? TimeOfDay(hour: hour, minute: minute)
        : null;
  }

  String _clock(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _choose() async {
    if (_choosing) return;
    _choosing = true;
    try {
      final start = await showTimePicker(
        context: context,
        initialTime: _existing(0) ?? const TimeOfDay(hour: 9, minute: 0),
        helpText: 'وقت بدء المحاضرة',
        cancelText: 'إلغاء',
        confirmText: 'التالي',
      );
      if (start == null || !mounted) return;
      final end = await showTimePicker(
        context: context,
        initialTime:
            _existing(1) ??
            TimeOfDay(hour: (start.hour + 1) % 24, minute: start.minute),
        helpText: 'وقت انتهاء المحاضرة',
        cancelText: 'إلغاء',
        confirmText: 'تأكيد',
      );
      if (end == null || !mounted) return;
      widget.controller.text = '${_clock(start)} - ${_clock(end)}';
    } finally {
      _choosing = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, child) => TextFormField(
          controller: widget.controller,
          readOnly: true,
          onTap: _choose,
          textDirection: TextDirection.ltr,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            labelText: 'وقت المحاضرة',
            hintText: 'اختياري — اختر وقت البدء والانتهاء',
            prefixIcon: const Icon(Icons.schedule_rounded),
            suffixIcon: value.text.isEmpty || !widget.allowClear
                ? null
                : IconButton(
                    tooltip: 'مسح الوقت',
                    onPressed: widget.controller.clear,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
      );
}
