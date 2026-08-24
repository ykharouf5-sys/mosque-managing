import 'package:dentalcare/auth/data/biometric_service.dart';
import 'package:dentalcare/management/presentation/sales_dashboard_screen.dart';
import 'package:dentalcare/management/presentation/settings_screen.dart';
import 'package:dentalcare/management/presentation/warehouse_dashboard_screen.dart';
import 'package:dentalcare/student/presentation/student_admin_dashboard.dart';
import 'package:dentalcare/student/presentation/student_profile_screen.dart';
import 'package:dentalcare/student/presentation/schedule_screen.dart';
import 'package:dentalcare/student/presentation/lessons_screen.dart';
import 'package:dentalcare/student/presentation/university_screen.dart';
import 'package:dentalcare/student/presentation/result_upload_screen.dart';
import 'package:dentalcare/store/presentation/cart_screen.dart';
import 'package:dentalcare/store/presentation/category_products_screen.dart';
import 'package:dentalcare/store/presentation/favorites_screen.dart';
import 'package:dentalcare/store/presentation/my_orders_screen.dart';
import 'package:dentalcare/store/presentation/order_confirmation_screen.dart';
import 'package:dentalcare/store/presentation/search_results_screen.dart';
import 'package:dentalcare/utils/app_locale.dart';
import 'package:dentalcare/utils/variable_colors.dart';
import 'package:dentalcare/auth/presentation/onboarding_screen.dart';
import 'package:dentalcare/auth/presentation/login_screen.dart';
import 'package:dentalcare/auth/presentation/register_screen.dart';
import 'package:dentalcare/auth/presentation/welcome_screen.dart';
import 'package:dentalcare/shared/data/app_database.dart';
import 'package:dentalcare/shared/data/api_config.dart';
import 'package:dentalcare/shared/cache/cache_manager.dart';
import 'package:dentalcare/shared/data/connectivity_service.dart';
import 'package:dentalcare/shared/data/auth_service.dart';
import 'package:dentalcare/shared/data/fcm_token_service.dart';
import 'package:dentalcare/shared/data/sync_service.dart';
import 'package:dentalcare/store/data/pending_order_service.dart';
import 'package:dentalcare/store/data/store_polling_service.dart';
import 'package:dentalcare/shared/providers/auth_provider.dart';
import 'package:dentalcare/shared/widgets/main_navigation_screen.dart';
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
  StorePollingService.init();

  runApp(const ProviderScope(child: MyApp()));
}

class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();
  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate>
    with WidgetsBindingObserver {
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      setState(() => _locked = true);
    }
    if (state == AppLifecycleState.resumed && _locked) {
      _unlock();
    }
  }

  Future<void> _unlock() async {
    final enabled = await BiometricService.isEnabled();
    if (!enabled) {
      if (mounted) setState(() => _locked = false);
      return;
    }
    final available = await BiometricService.isAvailable();
    if (!available) {
      if (mounted) setState(() => _locked = false);
      return;
    }
    final ok = await BiometricService.authenticate();
    if (mounted) setState(() => _locked = !ok);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    if (auth.isLoggedIn) {
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
          return const MainNavigationScreen();
        default:
          return const MainNavigationScreen();
      }
    }

    if (_locked) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fingerprint, size: 64, color: AppColors.primary),
              SizedBox(height: 16),
              Text(
                'الرجاء المصادقة',
                style: TextStyle(fontSize: 18, color: AppColors.textDark),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _unlock,
                icon: Icon(Icons.lock_open),
                label: Text('فتح التطبيق'),
              ),
            ],
          ),
        ),
      );
    }
    return const OnboardingScreen();
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
        final uid = event.session!.user.id;
        final role = event.session!.user.userMetadata['role'] as String? ?? '';
        ref.read(authProvider.notifier).setAuth(uid, role);
        currentUserId = uid;
        currentUserRole = role;
      } else {
        ref.read(authProvider.notifier).clearAuth();
        currentUserId = null;
        currentUserRole = null;
      }
    });
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
            '/student-home': (context) => const MainNavigationScreen(),
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
