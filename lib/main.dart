import 'package:studentry/auth/data/biometric_service.dart';
import 'package:studentry/management/presentation/sales_dashboard_screen.dart';
import 'package:studentry/management/presentation/settings_screen.dart';
import 'package:studentry/management/presentation/warehouse_dashboard_screen.dart';
import 'package:studentry/student/presentation/student_admin_dashboard.dart';
import 'package:studentry/student/presentation/student_profile_screen.dart';
import 'package:studentry/student/data/academic_store.dart';
import 'package:studentry/student/presentation/schedule_screen.dart';
import 'package:studentry/student/presentation/lessons_screen.dart';
import 'package:studentry/student/presentation/university_screen.dart';
import 'package:studentry/student/presentation/result_upload_screen.dart';
import 'package:studentry/store/presentation/cart_screen.dart';
import 'package:studentry/store/presentation/category_products_screen.dart';
import 'package:studentry/store/presentation/favorites_screen.dart';
import 'package:studentry/store/presentation/my_orders_screen.dart';
import 'package:studentry/store/presentation/order_confirmation_screen.dart';
import 'package:studentry/store/presentation/search_results_screen.dart';
import 'package:studentry/utils/app_locale.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:studentry/auth/presentation/onboarding_screen.dart';
import 'package:studentry/auth/presentation/login_screen.dart';
import 'package:studentry/auth/presentation/register_screen.dart';
import 'package:studentry/auth/presentation/welcome_screen.dart';
import 'package:studentry/auth/presentation/pending_membership_screen.dart';
import 'package:studentry/patients/presentation/providers/patient_providers.dart';
import 'package:studentry/shared/data/app_database.dart';
import 'package:studentry/shared/data/api_config.dart';
import 'package:studentry/shared/cache/cache_manager.dart';
import 'package:studentry/shared/data/connectivity_service.dart';
import 'package:studentry/shared/data/auth_service.dart';
import 'package:studentry/shared/data/fcm_token_service.dart';
import 'package:studentry/shared/data/sync_service.dart';
import 'package:studentry/store/data/pending_order_service.dart';
import 'package:studentry/store/data/store_polling_service.dart';
import 'package:studentry/store/presentation/providers/store_providers.dart';
import 'package:studentry/shared/providers/auth_provider.dart';
import 'package:studentry/shared/widgets/main_navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

String? currentUserId;
String? currentUserRole;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiConfig.validateForRelease(isRelease: kReleaseMode);
  currentUserId = null;

  final saved = await SharedPreferences.getInstance();
  final langCode = saved.getString('app_language');
  if (langCode != null) {
    AppLocale.localeNotifier.value = Locale(langCode);
  } else {
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    if (deviceLocale.languageCode == 'ar' ||
        deviceLocale.languageCode == 'en') {
      AppLocale.localeNotifier.value = Locale(deviceLocale.languageCode);
    }
  }

  // ═══ Local-First Initialization ═══
  await AppDatabase.database;
  await CacheManager.instance.init();
  ConnectivityService.init();
  await AuthService().init();
  try {
    await FcmTokenService.init(authenticated: AuthService().isLoggedIn);
  } catch (_) {}
  SyncService.init();
  await PendingOrderService.init();
  await StorePollingService.init();

  runApp(const ProviderScope(child: MyApp()));
}

class _AppLockGate extends ConsumerStatefulWidget {
  final Widget child;

  const _AppLockGate({required this.child});

  @override
  ConsumerState<_AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<_AppLockGate>
    with WidgetsBindingObserver {
  bool _locked = true;
  bool _lockStateReady = false;
  bool _unlockInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.paused) &&
        AuthService().isLoggedIn &&
        !_unlockInProgress &&
        mounted) {
      setState(() {
        _locked = true;
        _lockStateReady = true;
      });
    }
    if (state == AppLifecycleState.resumed && _locked) {
      _unlock();
    }
  }

  Future<void> _initializeLock() async {
    if (!AuthService().isLoggedIn) {
      if (mounted) {
        setState(() {
          _locked = false;
          _lockStateReady = true;
        });
      }
      return;
    }
    final enabled = await BiometricService.isEnabled();
    if (!mounted) return;
    setState(() {
      _locked = enabled;
      _lockStateReady = true;
    });
    if (enabled) await _unlock();
  }

  Future<void> _unlock() async {
    if (_unlockInProgress) return;
    if (mounted) {
      setState(() => _unlockInProgress = true);
    } else {
      _unlockInProgress = true;
    }
    try {
      final enabled = await BiometricService.isEnabled();
      if (!enabled) {
        if (mounted) {
          setState(() {
            _locked = false;
            _lockStateReady = true;
          });
        }
        return;
      }
      final available = await BiometricService.isAvailable();
      if (!available) {
        if (mounted) {
          setState(() {
            _locked = true;
            _lockStateReady = true;
          });
        }
        return;
      }
      final ok = await BiometricService.authenticate();
      if (mounted) {
        setState(() {
          _locked = !ok;
          _lockStateReady = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _unlockInProgress = false);
      } else {
        _unlockInProgress = false;
      }
    }
  }

  Future<void> _signOutFromLock() async {
    await AuthService().signOut();
    ref.read(authProvider.notifier).clearAuth();
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    if (mounted) {
      setState(() {
        _locked = false;
        _lockStateReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    ref.listen<bool>(authProvider.select((state) => state.isLoggedIn), (
      previous,
      isLoggedIn,
    ) {
      if (previous == isLoggedIn) return;
      if (isLoggedIn) {
        _initializeLock();
      } else if (mounted) {
        setState(() {
          _locked = false;
          _lockStateReady = true;
        });
      }
    });

    final showLock = auth.isLoggedIn && (!_lockStateReady || _locked);
    return AppLockOverlay(
      showLock: showLock,
      lockStateReady: _lockStateReady,
      unlockInProgress: _unlockInProgress,
      onUnlock: _unlock,
      onSignOut: _signOutFromLock,
      child: widget.child,
    );
  }
}

@visibleForTesting
class AppLockOverlay extends StatelessWidget {
  final Widget child;
  final bool showLock;
  final bool lockStateReady;
  final bool unlockInProgress;
  final VoidCallback onUnlock;
  final VoidCallback onSignOut;

  const AppLockOverlay({
    super.key,
    required this.child,
    required this.showLock,
    required this.lockStateReady,
    required this.unlockInProgress,
    required this.onUnlock,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: showLock,
          child: TickerMode(
            enabled: !showLock,
            child: IgnorePointer(ignoring: showLock, child: child),
          ),
        ),
        if (showLock)
          Positioned.fill(
            child: Material(
              color: AppColors.background,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!lockStateReady)
                      const CircularProgressIndicator()
                    else ...[
                      Icon(
                        Icons.fingerprint,
                        size: 64,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'الرجاء المصادقة',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: unlockInProgress ? null : onUnlock,
                        icon: const Icon(Icons.lock_open),
                        label: const Text('فتح التطبيق'),
                      ),
                      TextButton(
                        onPressed: unlockInProgress ? null : onSignOut,
                        child: const Text('تسجيل الخروج'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (!auth.isLoggedIn) return const OnboardingScreen();

    final role = auth.role ?? 'student';
    switch (role) {
      case 'admin':
      case 'sales_manager':
        return const SalesDashboardScreen();
      case 'student_manager':
        return const StudentAdminDashboard();
      case 'warehouse_manager':
        return const WarehouseDashboardScreen();
      case 'student':
        return ClinicalMembershipGate(
          hasActiveMembership: auth.hasActiveClinicalMembership,
          child: const MainNavigationScreen(),
        );
      default:
        return ClinicalMembershipGate(
          hasActiveMembership: auth.hasActiveClinicalMembership,
          child: const MainNavigationScreen(),
        );
    }
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    _initAuthListener();
  }

  void _initAuthListener() {
    final authService = AuthService();
    // Note: authProvider.build() already initializes the state from
    // AuthService().currentUser, so we must NOT call setAuth here —
    // it would modify a provider while the widget tree is building.
    currentUserId = authService.userId;
    currentUserRole = authService.role;
    authService.onAuthChange.listen((event) async {
      _invalidateUserScopedProviders();
      if (event.session?.user != null) {
        final user = event.session!.user;
        final uid = user.id;
        final role = user.role;
        ref.read(authProvider.notifier).setAuthUser(user);
        currentUserId = uid;
        currentUserRole = role;
      } else {
        ref.read(authProvider.notifier).clearAuth();
        currentUserId = null;
        currentUserRole = null;
      }
      await AcademicStore.instance.rebindToCurrentSession();
      await StorePollingService.rebindToCurrentSession();
    });
  }

  void _invalidateUserScopedProviders() {
    ref.invalidate(patientListProvider);
    ref.invalidate(appointmentListProvider);
    ref.invalidate(patientsProvider);
    ref.invalidate(appointmentsProvider);
    ref.invalidate(cartProvider);
    ref.invalidate(favoritesProvider);
    ref.invalidate(reviewsProvider);
    ref.invalidate(ordersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final locale = AppLocale.localeNotifier.value;
    return ScreenUtilInit(
      designSize: const Size(393, 852),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          builder: (context, child) =>
              _AppLockGate(child: child ?? const SizedBox.shrink()),
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: _buildTheme(),
          home: const _AuthGate(),
          routes: {
            '/onboarding': (context) => const OnboardingScreen(),
            '/welcome': (context) => const WelcomeScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/cart': (context) => const CartScreen(),
            '/order-confirmation': (context) => const OrderConfirmationScreen(),
            '/favorites': (context) => const FavoritesScreen(),
            '/settings': (context) => const SettingsScreen(),
            '/sales-dashboard': (context) => const SalesDashboardScreen(),
            '/my-orders': (context) => const MyOrdersScreen(),
            '/student-home': (context) => Consumer(
              builder: (context, ref, _) {
                final auth = ref.watch(authProvider);
                return ClinicalMembershipGate(
                  hasActiveMembership: auth.hasActiveClinicalMembership,
                  child: const MainNavigationScreen(),
                );
              },
            ),
            '/membership-pending': (context) => const PendingMembershipScreen(),
            '/schedule': (context) => const ScheduleScreen(),
            '/lessons': (context) => const LessonsScreen(),
            '/university': (context) => const UniversityScreen(),
            '/student-admin': (context) => const StudentAdminDashboard(),
            '/student-profile': (context) => const StudentProfileScreen(),
            '/result-upload': (context) => const ResultUploadScreen(),
            '/warehouse-dashboard': (context) =>
                const WarehouseDashboardScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/category-products') {
              final categoryId = settings.arguments as String;
              return MaterialPageRoute(
                builder: (_) => CategoryProductsScreen(categoryId: categoryId),
              );
            }
            if (settings.name == '/search-results') {
              final query = settings.arguments as String;
              return MaterialPageRoute(
                builder: (_) => _buildSearchResultsScreen(query),
              );
            }
            if (settings.name == '/promo-detail') {
              return MaterialPageRoute(builder: (_) => const CartScreen());
            }
            return null;
          },
        );
      },
    );
  }

  Widget _buildSearchResultsScreen(String query) {
    return SearchResultsScreen(query: query);
  }

  ThemeData _buildTheme() {
    final font = GoogleFonts.cairo().fontFamily;
    return ThemeData(
      fontFamily: font,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: font,
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textLight,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: EdgeInsets.symmetric(vertical: 16.h),
          textStyle: TextStyle(
            fontFamily: font,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          side: const BorderSide(color: AppColors.primary),
          padding: EdgeInsets.symmetric(vertical: 16.h),
          textStyle: TextStyle(
            fontFamily: font,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.divider, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: TextStyle(
          fontFamily: font,
          color: AppColors.textLightGray,
          fontSize: 14.sp,
        ),
        labelStyle: TextStyle(fontFamily: font, color: AppColors.textGrey),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
    );
  }
}
