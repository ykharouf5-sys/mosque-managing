import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:studentry/patients/data/patient_data.dart';
import 'package:studentry/patients/presentation/appointments_screen.dart';
import 'package:studentry/patients/presentation/add_patient_screen.dart';
import 'package:studentry/patients/presentation/new_appointment_screen.dart';
import 'package:studentry/patients/presentation/patient_profile_screen.dart';
import 'package:studentry/patients/presentation/patients_list_screen.dart';
import 'package:studentry/patients/presentation/providers/patient_providers.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/providers/auth_provider.dart';
import 'package:studentry/shared/widgets/app_bottom_nav.dart';
import 'package:studentry/shared/widgets/app_drawer.dart';
import 'package:studentry/shared/widgets/refresh_visibility.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/store/data/store_api_service.dart';
import 'package:studentry/store/presentation/product_detail_screen.dart';
import 'package:studentry/store/presentation/providers/store_providers.dart';
import 'package:studentry/student/data/academic_store.dart';
import 'home_dashboard_data.dart';
import 'home_search_screen.dart';
import 'widgets/home_dashboard_widgets.dart';

class StudentHomeScreen extends ConsumerStatefulWidget {
  final bool embedded, active;
  const StudentHomeScreen({
    super.key,
    this.embedded = false,
    this.active = true,
  });
  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  final _academic = AcademicStore.instance;
  @override
  void initState() {
    super.initState();
    _academic.addListener(_academicChanged);
    Future.microtask(() {
      if (mounted) ref.read(catalogProvider.notifier).restoreSnapshot();
    });
  }

  void _academicChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _academic.removeListener(_academicChanged);
    _academic.setViewActive(this, false);
    super.dispose();
  }

  Future<void> _refreshTodayData({bool force = false}) async {
    final patients = ref.read(patientListProvider.notifier);
    final appointments = ref.read(appointmentListProvider.notifier);
    await appointments.loadFromDb();
    final changed = await patients.refreshFromApi(force: force);
    if (!mounted) return;
    if (!changed) await appointments.loadFromDb();
    if (!mounted) return;
    ref.invalidate(homeTodayAppointmentsProvider);
    ref.invalidate(homeTodayExpensesProvider);
    final catalog = ref.read(catalogProvider.notifier);
    catalog.restoreSnapshot();
    await Future.wait([
      catalog.refreshCatalog(force: force),
      _academic.load(force: force),
    ]);
  }

  void _search({bool filter = false}) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => HomeSearchScreen(chooseSection: filter)),
  );
  Future<void> _openAppointment(Appointment appointment) async {
    try {
      final generation = AppDatabase.captureActiveDataGeneration();
      final rows = await AppDatabase.getAllPatients();
      AppDatabase.ensureDataGeneration(generation);
      if (!mounted) return;
      PatientProfile? patient;
      for (final row in rows) {
        if (row['id'] == appointment.patientId) {
          patient = patientRowToProfile(row);
          break;
        }
      }
      if (patient != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PatientProfileScreen(patient: patient!),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AppointmentsScreen()),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الموعد. حاول مجددًا.')),
        );
      }
    }
  }

  Future<void> _bannerAction(PromoBanner? banner) async {
    if (banner?.productId != null) {
      try {
        final session = AuthService().sessionGeneration;
        final response = await ApiClient.instance.get(
          '/public/store/products/${banner!.productId}',
        );
        if (!mounted || session != AuthService().sessionGeneration) return;
        final row = Map<String, dynamic>.from(response.data['data'] as Map);
        final product = Product.fromJson(StoreApiService.rowToProductMap(row));
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsScreen(product: product),
          ),
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر فتح المنتج. تحقق من الاتصال وحاول مجددًا.'),
            ),
          );
        }
      }
      return;
    }
    if (banner?.categoryId != null) {
      Navigator.pushNamed(
        context,
        '/category-products',
        arguments: banner!.categoryId,
      );
      return;
    }
    final route = banner?.targetRoute ?? '/schedule';
    const allowed = {
      '/schedule',
      '/university',
      '/store',
      '/lessons',
      '/my-orders',
      '/student-profile',
      '/notifications',
      '/settings',
      '/promo-detail',
    };
    Navigator.pushNamed(context, allowed.contains(route) ? route : '/schedule');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authProvider);
    final p = HomePalette.of(context);
    final now = DateTime.now();
    final loaded = ref.watch(homeTodayAppointmentsProvider);
    final appointments =
        loaded.value ??
        ref
            .watch(appointmentListProvider)
            .where((a) => sameHomeDay(a.date, now))
            .toList();
    final expenses = ref.watch(homeTodayExpensesProvider);
    final banners = ref
        .watch(catalogProvider.select((state) => state.banners))
        .where((banner) => banner.isHomeBanner)
        .toList();
    final auth = AuthService();
    final name = auth.fullName?.trim() ?? '';
    final count = appointments
        .map((a) => a.patientId.isEmpty ? a.patientName : a.patientId)
        .toSet()
        .length;
    final remaining = appointments
        .where((a) => a.appointmentDateTime.isAfter(now))
        .length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshVisibility(
        active: widget.active,
        onChanged: (visible) {
          _academic.setViewActive(this, visible);
          if (visible) _refreshTodayData();
        },
        child: Scaffold(
          backgroundColor: p.background,
          drawer: const AppDrawer(),
          drawerEnableOpenDragGesture: !widget.embedded,
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: HomePalette.teal,
              onRefresh: () => _refreshTodayData(force: true),
              child: LayoutBuilder(
                builder: (context, constraints) => Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Builder(
                          builder: (context) => HomeHeader(
                            name: name,
                            avatarUrl: auth.avatarUrl,
                            reminders: remaining,
                            onMenu: () => Scaffold.of(context).openDrawer(),
                            onProfile: () =>
                                Navigator.pushNamed(context, '/settings'),
                            onNotifications: () =>
                                Navigator.pushNamed(context, '/notifications'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        HomeSearchBar(
                          onSearch: () => _search(),
                          onFilter: () => _search(filter: true),
                        ),
                        const SizedBox(height: 12),
                        HomeBannerCarousel(
                          banners: banners,
                          onAction: _bannerAction,
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, box) {
                            final stats = [
                              HomeStat(
                                title: 'مرضى اليوم',
                                value: loaded.hasError ? '—' : '$count',
                                icon: Icons.groups_rounded,
                                color: HomePalette.teal,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PatientsListScreen(),
                                  ),
                                ),
                              ),
                              HomeStat(
                                title: 'مصروفات اليوم',
                                value: expenses.hasValue
                                    ? '${NumberFormat('#,##0.##').format(expenses.value)} ل.س'
                                    : '—',
                                explanation: expenses.hasValue
                                    ? 'قيمة طلبات المتجر المنشأة اليوم والمؤكدة، باستثناء المعلقة والملغاة والمرفوضة'
                                    : 'تعذر تحميل قيمة الطلبات؛ اسحب للتحديث',
                                icon: Icons.account_balance_wallet_rounded,
                                color: HomePalette.teal,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/my-orders'),
                              ),
                              HomeStat(
                                title: 'محاضرات اليوم',
                                value:
                                    _academic.isLoading &&
                                        _academic.enrollments.isEmpty
                                    ? '—'
                                    : '${todayLectureCount(_academic.enrollments, now)}',
                                icon: Icons.school_rounded,
                                color: HomePalette.teal,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/schedule'),
                              ),
                              HomeStat(
                                title: 'المواعيد اليوم',
                                value: loaded.hasError
                                    ? '—'
                                    : '${appointments.length}',
                                icon: Icons.calendar_month_rounded,
                                color: HomePalette.teal,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AppointmentsScreen(),
                                  ),
                                ),
                              ),
                            ];
                            return HomeStatisticsGrid(stats: stats);
                          },
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Text(
                              'اليوم',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: p.text,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                children: [
                                  const Icon(
                                    Icons.calendar_month_rounded,
                                    size: 17,
                                    color: HomePalette.teal,
                                  ),
                                  Text(
                                    DateFormat(
                                      'EEEE d MMMM yyyy',
                                      'ar',
                                    ).format(now),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: p.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (loaded.hasError)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'تعذر تحميل بعض البيانات؛ اسحب للتحديث.',
                              style: TextStyle(color: p.muted),
                            ),
                          ),
                        HomeTodayCard(
                          showAddButton: false,
                          appointments: appointments,
                          onAppointment: _openAppointment,
                          onAdd: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NewAppointmentScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        HomeDashboardActions(
                          onAddAppointment: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NewAppointmentScreen(),
                            ),
                          ),
                          onAddPatient: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddPatientScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: widget.embedded
              ? null
              : const AppBottomNav(selectedIndex: 0),
        ),
      ),
    );
  }
}
