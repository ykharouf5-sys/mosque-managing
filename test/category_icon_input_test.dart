import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/management/presentation/widgets/category_icon_input.dart';

void main() {
  testWidgets('category icon remains optional and accepts a manual link', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CategoryIconInput(
            controller: controller,
            onPick: () async => null,
          ),
        ),
      ),
    );

    expect(controller.text, isEmpty);
    await tester.tap(find.text('اختيار أيقونة من الجهاز (اختياري)'));
    await tester.pump();
    expect(controller.text, isEmpty);

    await tester.enterText(find.byType(TextField), 'https://example.com/icon.png');
    expect(controller.text, 'https://example.com/icon.png');
  });
}
