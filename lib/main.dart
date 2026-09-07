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
import 'package:studentry/auth/presentation/onboarding_screen.dart';
import 'package:studentry/auth/presentation/login_screen.dart';
import 'package:studentry/auth/presentation/register_screen.dart';
import 'package:studentry/auth/presentation/welcome_screen.dart';
import 'package:studentry/patients/presentation/providers/patient_providers.dart';
import 'package:studentry/patients/presentation/notifications_screen.dart';
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
            SyncService.syncNow(force: true),
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
          minimumSize: const Size(64, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
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
          minimumSize: const Size(64, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          side: const BorderSide(color: AppColors.primary),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          textStyle: TextStyle(
            fontFamily: font,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          tapTargetSize: MaterialTapTargetSize.padded,
          textStyle: TextStyle(
            fontFamily: font,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
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
