import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:studentry/patients/presentation/widgets/appointment_datetime_picker.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  for (final size in const [Size(320, 640), Size(393, 852), Size(800, 1000)]) {
    testWidgets('appointment picker fits ${size.width}x${size.height}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showAppointmentDateTimePicker(
                  context: context,
                  initialDate: DateTime(2026, 9, 2),
                  initialTime: const TimeOfDay(hour: 9, minute: 0),
                ),
                child: const Text('فتح'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('فتح'));
      await tester.pumpAndSettle();

      expect(find.text('اختر الموعد'), findsOneWidget);
      expect(find.text('تأكيد الموعد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
