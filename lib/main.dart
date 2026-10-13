import 'dart:async';

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
import 'package:studentry/utils/app_theme.dart';
import 'package:studentry/auth/presentation/onboarding_screen.dart';
import 'package:studentry/auth/presentation/login_screen.dart';
import 'package:studentry/auth/presentation/register_screen.dart';
import 'package:studentry/auth/presentation/welcome_screen.dart';
import 'package:studentry/patients/presentation/providers/patient_providers.dart';
import 'package:studentry/patients/presentation/notifications_screen.dart';
import 'package:studentry/patients/data/notification_service.dart';
import 'package:studentry/shared/data/api_config.dart';
import 'package:studentry/shared/data/api_client.dart';
import 'package:studentry/shared/widgets/refresh_visibility.dart';
import 'package:studentry/shared/data/storage_usage_service.dart';
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
import 'package:studentry/store/data/store_api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

String? currentUserId;
String? currentUserRole;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Holds a fatal configuration error (e.g. release built without
/// `--dart-define=API_BASE_URL=...`) so the app can still boot to an
/// explanatory screen instead of dying on the native splash with zero
/// feedback. Never throws before [runApp].
String? _configError;

const _prefsTimeout = Duration(seconds: 5);
const _serviceInitTimeout = Duration(seconds: 15);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    ApiConfig.validateForRelease(isRelease: kReleaseMode);
  } catch (e) {
    // Brick-wall guard: a misbuilt release must show WHAT is wrong instead
    // of hanging forever on the static splash logo.
    _configError = e.toString();
    debugPrint('[boot] config error: $e');
  }
  currentUserId = null;

  try {
    final saved = await SharedPreferences.getInstance().timeout(
      _prefsTimeout,
      onTimeout: () {
        debugPrint('[boot] SharedPreferences.getInstance timed out');
        throw TimeoutException('SharedPreferences timed out');
      },
    );
    AppLocale.localeNotifier.value = Locale(
      saved.getString('app_language') == 'en' ? 'en' : 'ar',
    );
  } catch (e) {
    debugPrint('[boot] language prefs skipped: $e');
  }

  // The encrypted account database is opened only after authentication.
  try {
    await CacheManager.instance.init().timeout(
      _prefsTimeout,
      onTimeout: () => debugPrint('[boot] CacheManager.init timed out'),
    );
  } catch (e) {
    debugPrint('[boot] CacheManager.init skipped: $e');
  }
  try {
    ConnectivityService.init();
  } catch (e) {
    debugPrint('[boot] ConnectivityService.init skipped: $e');
  }
  try {
    await AuthService().init().timeout(
      _serviceInitTimeout,
      onTimeout: () {
        debugPrint('[boot] AuthService.init timed out');
        throw TimeoutException('AuthService.init timed out');
      },
    );
  } catch (e) {
    debugPrint('[boot] AuthService.init skipped: $e');
  }
  try {
    await FcmTokenService.init(
      authenticated: AuthService().isLoggedIn,
    ).timeout(_serviceInitTimeout);
  } catch (_) {}
  try {
    SyncService.init();
  } catch (e) {
    debugPrint('[boot] SyncService.init skipped: $e');
  }
  try {
    await PendingOrderService.init().timeout(_serviceInitTimeout);
  } catch (e) {
    debugPrint('[boot] PendingOrderService.init skipped: $e');
  }
  try {
    await StorePollingService.init().timeout(_serviceInitTimeout);
  } catch (e) {
    debugPrint('[boot] StorePollingService.init skipped: $e');
  }

  debugPrint('[boot] runApp');
  runApp(const ProviderScope(child: MyApp()));
  // Compiled runtime never uses hot-reload VM payloads from an older debug
  // install. Clean only that exact triplet; keep all account documents intact.
  unawaited(
    StorageUsageService.cleanupDevelopmentArtifacts().catchError((_) => 0),
  );
}

/// Shown when the app was built without a valid release configuration
/// (missing/invalid `API_BASE_URL`). Explains the problem instead of a dead
/// splash screen.
class ConfigErrorScreen extends StatelessWidget {
  const ConfigErrorScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.settings_applications_outlined,
                    size: 56,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'تعذر تشغيل التطبيق',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text(
                    'أعد بناء نسخة الـ release مع الرابط الصحيح.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
        return auth.profileCompleted
            ? const MainNavigationScreen()
            : const StudentProfileScreen();
      default:
        return const MainNavigationScreen();
    }
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  StreamSubscription? _authSubscription;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLocale.localeNotifier.addListener(_localeChanged);
    _setAppActive(
      WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
    _initAuthListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(NotificationService.handlePendingLaunchResponse());
      // Auth initialization happens before the listener is attached. Restore
      // the academic cache/polling binding for an already signed-in account.
      if (AuthService().isLoggedIn) {
        unawaited(AcademicStore.instance.rebindToCurrentSession());
      }
    });
  }

  void _initAuthListener() {
    final authService = AuthService();
    // Note: authProvider.build() already initializes the state from
    // AuthService().currentUser, so we must NOT call setAuth here —
    // it would modify a provider while the widget tree is building.
    currentUserId = authService.userId;
    currentUserRole = authService.role;
    _authSubscription = authService.onAuthChange.listen((event) async {
      if (event.session?.user != null) {
        final user = event.session!.user;
        final uid = user.id;
        final role = user.role;
        ref.read(authProvider.notifier).setAuthUser(user);
        currentUserId = uid;
        currentUserRole = role;
        if (event.rebindData) {
          _invalidateUserScopedProviders();
          await Future.wait<dynamic>([
            PendingOrderService.retryPending(),
            SyncService.syncNow(),
            AcademicStore.instance.rebindToCurrentSession(),
            StorePollingService.rebindToCurrentSession(),
          ]);
        }
      } else {
        _invalidateUserScopedProviders();
        ref.read(authProvider.notifier).clearAuth();
        currentUserId = null;
        currentUserRole = null;
        await Future.wait<void>([
          AcademicStore.instance.rebindToCurrentSession(),
          StorePollingService.rebindToCurrentSession(),
        ]);
      }
    });
  }

  void _invalidateUserScopedProviders() {
    ApiClient.instance.invalidateReads();
    StoreApiService.resetSession();
    ref.invalidate(catalogProvider);
    ref.invalidate(patientListProvider);
    ref.invalidate(patientDirectoryProvider);
    ref.invalidate(appointmentListProvider);
    ref.invalidate(patientsProvider);
    ref.invalidate(appointmentsProvider);
    ref.invalidate(cartProvider);
    ref.invalidate(favoritesProvider);
    ref.invalidate(reviewsProvider);
    ref.invalidate(ordersProvider);
  }

  void _setAppActive(bool active) {
    SyncService.setAppActive(active);
    StorePollingService.setAppActive(active);
    AcademicStore.instance.setAppActive(active);
  }

  void _localeChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _setAppActive(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppLocale.localeNotifier.removeListener(_localeChanged);
    _authSubscription?.cancel();
    super.dispose();
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
          navigatorObservers: [refreshRouteObserver],
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: _buildTheme(),
          home: _configError != null
              ? ConfigErrorScreen(message: _configError!)
              : const _AuthGate(),
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
              builder: (context, ref, _) => const MainNavigationScreen(),
            ),
            '/store': (context) => const MainNavigationScreen(initialIndex: 3),
            '/schedule': (context) => const ScheduleScreen(),
            '/lessons': (context) => const LessonsScreen(),
            '/university': (context) => const UniversityScreen(),
            '/student-admin': (context) => const StudentAdminDashboard(),
            '/student-profile': (context) => const StudentProfileScreen(),
            '/result-upload': (context) => const ResultUploadScreen(),
            '/warehouse-dashboard': (context) =>
                const WarehouseDashboardScreen(),
            '/notifications': (context) => const NotificationsScreen(),
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

  ThemeData _buildTheme() => AppTheme.light(
    fontFamily: GoogleFonts.cairo().fontFamily,
    fontSize: 16.sp,
    titleSize: 18.sp,
    fieldSize: 14.sp,
    buttonPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
    inputPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
  );
}
