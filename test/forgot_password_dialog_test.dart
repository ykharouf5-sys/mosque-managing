import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/auth/presentation/forgot_password_dialog.dart';

void main() {
  testWidgets('invalid email does not request a reset code', (tester) async {
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ForgotPasswordDialog(
          initialEmail: 'invalid',
          sendCode: (_) async {
            requests++;
            return 60;
          },
        ),
      ),
    );
    await tester.tap(find.text('إرسال الرمز'));
    await tester.pump();
    expect(requests, 0);
    expect(find.text('أدخل بريداً إلكترونياً صحيحاً'), findsOneWidget);
  });

  testWidgets('sending blocks duplicates and returns the email and cooldown', (
    tester,
  ) async {
    final response = Completer<int>();
    var requests = 0;
    String? requestedEmail;
    PasswordResetRequest? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<PasswordResetRequest>(
                  context: context,
                  builder: (_) => ForgotPasswordDialog(
                    initialEmail: 'Student@Example.com',
                    sendCode: (email) {
                      requests++;
                      requestedEmail = email;
                      return response.future;
                    },
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إرسال الرمز'));
    await tester.pump();
    expect(requests, 1);
    expect(requestedEmail, 'student@example.com');
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'إلغاء'))
          .onPressed,
      isNull,
    );
    response.complete(45);
    await tester.pumpAndSettle();
    expect(result?.email, 'student@example.com');
    expect(result?.resendSeconds, 45);
    expect(find.byType(ForgotPasswordDialog), findsNothing);
  });

  testWidgets('send failure keeps the email and permits retry', (tester) async {
    var requests = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ForgotPasswordDialog(
          initialEmail: 'student@example.com',
          sendCode: (_) async {
            requests++;
            throw Exception('لا يوجد اتصال بالإنترنت');
          },
        ),
      ),
    );
    await tester.tap(find.text('إرسال الرمز'));
    await tester.pumpAndSettle();
    expect(find.textContaining('لا يوجد اتصال بالإنترنت'), findsOneWidget);
    expect(find.text('student@example.com'), findsOneWidget);
    await tester.tap(find.text('إرسال الرمز'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(tester.takeException(), isNull);
  });
}
