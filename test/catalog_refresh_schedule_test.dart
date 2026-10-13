import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studentry/store/data/catalog_refresh_policy.dart';
import 'package:studentry/store/data/catalog_refresh_schedule.dart';
import 'package:studentry/store/presentation/widgets/catalog_batch_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('batch preview runs without native dependencies', (tester) async {
    await tester.pumpWidget(catalogBatchPreview());
    expect(find.textContaining('/120'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
    'every identity gets one stable slot within two hours and repeats exactly',
    () {
      final now = DateTime.utc(2026, 10, 4, 12, 17, 31);
      final batches = <int>{};
      for (var i = 0; i < 1000; i++) {
        final identity = 'account-$i:device-$i';
        final slot = CatalogRefreshPolicy.nextSlot(now, identity);
        expect(slot.isAfter(now), true);
        expect(
          slot.difference(now),
          lessThanOrEqualTo(CatalogRefreshPolicy.cycle),
        );
        expect(
          CatalogRefreshPolicy.nextSlot(slot, identity).difference(slot),
          CatalogRefreshPolicy.cycle,
        );
        expect(CatalogRefreshPolicy.nextSlot(now, identity), slot);
        batches.add(CatalogRefreshPolicy.batch(identity));
      }
      expect(batches.length, greaterThan(100));
    },
  );

  test(
    'navigation and new scheduler instances preserve the saved slot',
    () async {
      SharedPreferences.setMockInitialValues({
        'catalog_refresh_installation_v1': 'device-1',
      });
      var now = DateTime.utc(2026, 10, 4, 12);
      final schedule = CatalogRefreshSchedule(now: () => now);
      await schedule.prepare('a');
      final due = schedule.nextRefreshAt;
      await schedule.prepare('a');
      expect(schedule.nextRefreshAt, due);
      final restored = CatalogRefreshSchedule(now: () => now);
      await restored.prepare('a');
      expect(restored.nextRefreshAt, due);
      now = due!.add(const Duration(minutes: 10));
      await restored.prepare('a');
      expect(restored.delay, greaterThan(Duration.zero));
      expect(
        restored.delay,
        lessThanOrEqualTo(const Duration(minutes: 5, seconds: 1)),
      );
    },
  );

  test(
    'successful scheduled and manual updates rejoin the two-hour cycle',
    () async {
      SharedPreferences.setMockInitialValues({
        'catalog_refresh_installation_v1': 'device-1',
      });
      var now = DateTime.utc(2026, 10, 4, 12);
      final schedule = CatalogRefreshSchedule(now: () => now);
      await schedule.prepare('a');
      now = schedule.nextRefreshAt!;
      await schedule.completed(success: true);
      expect(schedule.delay, CatalogRefreshPolicy.cycle);
      now = now.add(const Duration(minutes: 30));
      await schedule.completed(success: true);
      expect(schedule.delay, const Duration(minutes: 90));
    },
  );

  test(
    'failures back off, and resume cannot reset them into an immediate storm',
    () async {
      SharedPreferences.setMockInitialValues({
        'catalog_refresh_installation_v1': 'device-1',
      });
      final now = DateTime.utc(2026, 10, 4, 12);
      final schedule = CatalogRefreshSchedule(now: () => now);
      await schedule.prepare('a');
      await schedule.completed(success: false);
      expect(schedule.delay.inMinutes, inInclusiveRange(5, 6));
      final retry = schedule.nextRefreshAt;
      await schedule.prepare('a');
      expect(schedule.nextRefreshAt, retry);
      for (var i = 0; i < 8; i++) {
        await schedule.completed(success: false);
      }
      expect(schedule.delay.inMinutes, inInclusiveRange(30, 31));
    },
  );

  test('accounts and installations have independent slots', () async {
    SharedPreferences.setMockInitialValues({
      'catalog_refresh_installation_v1': 'device-1',
    });
    final now = DateTime.utc(2026, 10, 4, 12);
    final schedule = CatalogRefreshSchedule(now: () => now);
    await schedule.prepare('a');
    final first = schedule.nextRefreshAt;
    await schedule.prepare('b');
    expect(schedule.nextRefreshAt, isNot(first));
    await schedule.prepare('a');
    expect(schedule.nextRefreshAt, first);
    expect(CatalogRefreshPolicy.nextSlot(now, 'a:device-2'), isNot(first));
  });
}
