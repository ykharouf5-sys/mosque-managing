import 'package:flutter/material.dart';
import 'package:yaman/Screen/signscreen.dart';

import 'package:yaman/Screen/Welcome_Screen.dart';
import 'package:yaman/Screen/regestration_Screen.dart';
import 'package:yaman/Screen/AdminChatScreen.dart';
import 'package:yaman/dashboard/Gifts.dart';
import 'package:yaman/dashboard/dashboard.dart';
import 'package:yaman/dashboard/student_managment.dart';
import 'package:yaman/dashboard/teacher_managment.dart';
import 'package:yaman/dashboard/trackingStudent.dart';
import 'package:yaman/widget/admin.dart';
import 'package:yaman/Screen/role_selection_screen.dart';
import 'package:yaman/widgets/supabase_test_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yaman/services/sync_queue_service.dart';
import 'package:yaman/services/local_notification_service.dart';
import 'package:yaman/services/prayer_times_service.dart';
import 'package:yaman/services/auto_sync_service.dart';
import 'package:yaman/widget/variable.dart' as palette;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yaman/Screen/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Firebase removed
    
    // Initialize Supabase
    await Supabase.initialize(
      url: "https://fjklkcqjqlhfaefuqrmp.supabase.co",
      anonKey:
          "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZqa2xrY3FqcWxoZmFlZnVxcm1wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU0MDU5NDAsImV4cCI6MjA4MDk4MTk0MH0.eyG0vl_jVV0MiOUgjgL7bybgix0o8eAQsosx0cIHHNA",
    );
    print('Supabase initialized successfully');
    
    // Initialize Sync Queue for Offline Support
    await SyncQueueService().initialize();
    
    // Initialize Local Notifications
    await LocalNotificationService().initialize();
    
    // Initialize Auto-Sync (يزامن كل البيانات تلقائياً بدون أي زر)
    await AutoSyncService().initialize();
    
    // Firebase Cloud Messaging removed
    
    // Initialize and schedule prayer times notifications
    await _initializePrayerNotifications();
  } catch (e) {
    print('Error initializing Services: $e');
  }

  // Initialization logic moved to SplashScreen to prevent slow startup
  runApp(ProviderScope(child: const MyApp()));
}

/// Initialize prayer times and schedule daily notifications
Future<void> _initializePrayerNotifications() async {
  try {
    print('🕌 Initializing prayer times notifications...');
    
    // Get today's prayer times
    final prayerTimesService = PrayerTimesService();
    final prayerTimes = await prayerTimesService.getTodayPrayerTimesAsDateTime();
    
    if (prayerTimes != null) {
      // Schedule notifications for today's prayers
      await LocalNotificationService().schedulePrayerNotifications(prayerTimes);
      print('✅ Prayer notifications scheduled for today');
    } else {
      print('⚠️ Could not fetch prayer times');
    }
  } catch (e) {
    print('❌ Error initializing prayer notifications: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: palette.regsin,
          brightness: Brightness.light,
          primary: palette.regsin,
          secondary: palette.textcolor,
        ),
        scaffoldBackgroundColor: palette.backcolor,
        appBarTheme: AppBarTheme(
          centerTitle: true,
          backgroundColor: palette.backcolor,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: palette.textcolor.withValues(alpha: 0.12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: palette.textcolor.withValues(alpha: 0.5),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: Color.fromARGB(255, 214, 182, 0),
              width: 2,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: palette.regsin,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      initialRoute: "/splash",
      routes: {
        "/splash": (context) => const SplashScreen(),
        "/welscreen": (context) => const WelcomeScreen(),
        "/regscreen": (context) => Regestration(),
        "/signscreen": (context) => const SignScreen(),
        "/role_selection": (context) => const RoleSelectionScreen(),

        "/chatscreen": (context) => const AdminChatScreen(),
        "/dashboard": (context) => Dashboard(),
        "/teacher": (context) => Tmanagment(),
        "/students": (context) => StudentManagment(),
        "/track": (context) => Tracking(),
        "/gifts": (context) => Gifts(),
        "/admin": (context) => Admin(),
        "/supabase_test": (context) => const SupabaseTestWidget(),
        // "/sinterface":(context)=>StudentInterface(student: Student(Sname: Sname, Snumber: Snumber))
      },
    );
  }
}
