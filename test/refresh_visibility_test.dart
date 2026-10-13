import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/shared/widgets/refresh_visibility.dart';

void main() {
  testWidgets('refresh follows foreground, route, and selected tab', (
    tester,
  ) async {
    final reports = <bool>[];
    final selected = ValueNotifier(true);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [refreshRouteObserver],
        home: ValueListenableBuilder<bool>(
          valueListenable: selected,
          builder: (_, value, child) => RefreshVisibility(
            active: value,
            onChanged: reports.add,
            child: const Scaffold(body: Text('test')),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(reports, [true]);
    selected.value = false;
    await tester.pump();
    expect(reports.last, isFalse);
    selected.value = true;
    await tester.pump();
    expect(reports.last, isTrue);
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('covered')),
      ),
    );
    await tester.pumpAndSettle();
    expect(reports.last, isFalse);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(reports.last, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(reports.last, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(reports.last, isTrue);
    await tester.pumpWidget(const SizedBox());
    selected.dispose();
  });

  testWidgets('a covered, unselected tab does not resume refreshing', (
    tester,
  ) async {
    final reports = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: RefreshVisibility(
          active: false,
          onChanged: reports.add,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(reports, [false]);
  });
}
