import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/shared/data/sync_service.dart';
import 'package:studentry/shared/widgets/sync_status_indicator.dart';

void main() {
  tearDown(() {
    SyncService.status.value = const SyncStatusSnapshot();
  });

  testWidgets('stays hidden when the outbox is empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SyncStatusIndicator())),
    );

    expect(find.byType(SizedBox), findsOneWidget);
    expect(find.textContaining('مزامنة'), findsNothing);
  });

  testWidgets('shows waiting changes without requiring user action', (
    tester,
  ) async {
    SyncService.status.value = const SyncStatusSnapshot(waiting: 3);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SyncStatusIndicator())),
    );

    expect(find.text('3 تغييرات بانتظار المزامنة'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('shows permanent failures separately', (tester) async {
    SyncService.status.value = const SyncStatusSnapshot(failedPermanent: 2);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SyncStatusIndicator())),
    );

    expect(find.text('تعذرت مزامنة 2 تغييرات'), findsOneWidget);
  });
}
