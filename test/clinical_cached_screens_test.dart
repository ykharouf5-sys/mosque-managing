import 'dart:async';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studentry/patients/data/patient_data.dart';
import 'package:studentry/patients/presentation/patients_list_screen.dart';
import 'package:studentry/patients/presentation/appointments_screen.dart';
import 'package:studentry/patients/presentation/providers/patient_providers.dart';
import 'package:studentry/shared/widgets/refresh_visibility.dart';
import 'package:studentry/shared/widgets/refresh_visibility_preview.dart';

class CachedDirectory extends PatientDirectoryNotifier {
  final refresh = Completer<void>();
  int refreshes = 0;
  @override
  List<PatientProfile> build() => [
    PatientProfile.fromJson({'id': 'local-patient', 'name': 'مريض محلي'}),
  ];
  @override
  bool get hasMore => false;
  @override
  Future<void> refreshFromApi({bool force = false}) {
    refreshes++;
    return refresh.future;
  }

  void rebuild() => state = [...state];
}

class CachedAppointments extends AppointmentListNotifier {
  int remoteRequests = 0;
  final appointment = Appointment(
    id: 'local-appt',
    time: '10:00',
    patientName: 'موعد محلي',
    treatment: '',
    status: 'pending',
    patientId: 'local-patient',
    date: DateTime.now(),
  );
  @override
  List<Appointment> build() => [appointment];
  @override
  Future<AppointmentDatePage> loadDatePage(
    DateTime date, {
    int page = 1,
    bool remote = false,
    bool manual = false,
  }) async {
    if (remote) remoteRequests++;
    return AppointmentDatePage(
      appointments: [appointment],
      currentPage: 1,
      lastPage: 1,
    );
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('ar'));
  testWidgets(
    'patients render local cache before a blocked background refresh; rebuild does not refresh',
    (tester) async {
      final cached = CachedDirectory();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [patientDirectoryProvider.overrideWith(() => cached)],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            child: MaterialApp(
              navigatorObservers: [refreshRouteObserver],
              home: const PatientsListScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('مريض محلي'), findsOneWidget);
      expect(cached.refresh.isCompleted, isFalse);
      expect(cached.refreshes, 1);
      cached.rebuild();
      await tester.pump();
      await tester.pump();
      expect(cached.refreshes, 1);
      cached.refresh.complete();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'an inactive appointments tab displays cached data with no remote date GET',
    (tester) async {
      final cached = CachedAppointments();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appointmentListProvider.overrideWith(() => cached)],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            child: MaterialApp(
              navigatorObservers: [refreshRouteObserver],
              home: const AppointmentsScreen(embedded: true, active: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('موعد محلي'), findsOneWidget);
      expect(cached.remoteRequests, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('clinical preview manual guard and idle clock advancement', (
    tester,
  ) async {
    await tester.pumpWidget(refreshVisibilityPreview());
    await tester.pump();
    expect(find.textContaining('طلبات السحب: 1'), findsOneWidget);
    await tester.tap(find.text('تحديث يدوي'));
    await tester.pump();
    expect(find.textContaining('طلبات السحب: 2'), findsOneWidget);
    await tester.tap(find.text('تحديث يدوي'));
    await tester.pump();
    expect(find.textContaining('طلبات السحب: 2'), findsOneWidget);
    await tester.tap(find.text('تقدّم 20 ثانية بدون إرسال طلب'));
    await tester.pump();
    expect(find.textContaining('طلبات السحب: 2'), findsOneWidget);
  });
}
