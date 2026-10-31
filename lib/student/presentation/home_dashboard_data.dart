import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:studentry/patients/data/patient_data.dart';
import 'package:studentry/patients/presentation/providers/patient_providers.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/shared/data/sync_service.dart';
import 'package:studentry/shared/providers/auth_provider.dart';
import 'package:studentry/store/data/store_api_service.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/store/presentation/providers/store_providers.dart';
import 'package:studentry/student/data/subject_models.dart';

bool sameHomeDay(DateTime value, DateTime day) {
  final local = value.toLocal();
  return local.year == day.year &&
      local.month == day.month &&
      local.day == day.day;
}

int todayLectureCount(Iterable<StudentSubject> enrollments, DateTime date) {
  const names = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
  String normalize(String value) =>
      value.replaceAll('أ', 'ا').replaceAll('إ', 'ا').trim();
  final day = normalize(names[date.weekday - 1]);
  return enrollments
      .where((e) => e.scheduleDays.any((d) => normalize(d) == day))
      .length;
}

double confirmedTodayOrderTotal(Iterable<Order> orders, DateTime date) => orders
    .where(
      (o) =>
          !o.awaitingSync &&
          sameHomeDay(o.createdAt, date) &&
          const {
            OrderStatus.accepted,
            OrderStatus.preparing,
            OrderStatus.outForDelivery,
            OrderStatus.delivered,
          }.contains(o.status),
    )
    .fold(0.0, (sum, order) => sum + order.totalPrice);

/// Reads the whole selected day, rather than the first 25 appointments in a list.
final homeTodayAppointmentsProvider =
    FutureProvider.autoDispose<List<Appointment>>((ref) async {
      ref.watch(authProvider);
      ref.watch(appointmentListProvider);
      Future<void> reload() async => ref.invalidateSelf();
      SyncService.addDbReloadListener(reload);
      ref.onDispose(() => SyncService.removeDbReloadListener(reload));
      if (!AuthService().isLoggedIn) return const [];
      final generation = AppDatabase.captureActiveDataGeneration();
      final rows = await AppDatabase.getAppointmentsForDate(DateTime.now());
      AppDatabase.ensureDataGeneration(generation);
      final result =
          rows
              .map(appointmentRowToAppointment)
              .whereType<Appointment>()
              .toList()
            ..sort(
              (a, b) => a.appointmentDateTime.compareTo(b.appointmentDateTime),
            );
      return result;
    });

/// Existing authenticated cursor-paginated feed, without new APIs or writes.
/// Failed/offline reads remain unavailable rather than becoming a fake zero.
final homeTodayExpensesProvider = FutureProvider.autoDispose<double>((
  ref,
) async {
  ref.watch(authProvider);
  ref.watch(ordersProvider.select((state) => state.orders));
  if (!AuthService().isLoggedIn) throw StateError('Authentication required');
  final now = DateTime.now();
  final session = AuthService().sessionGeneration;
  final start = DateTime(now.year, now.month, now.day).toUtc();
  final feed = await StoreApiService.fetchOrderChanges(start.toIso8601String());
  if (session != AuthService().sessionGeneration) {
    throw const StaleAccountDataException();
  }
  final orders = feed.rows.map(
    (row) => Order.fromJson(StoreApiService.rowToOrderMap(row)),
  );
  return confirmedTodayOrderTotal(orders, now);
});
