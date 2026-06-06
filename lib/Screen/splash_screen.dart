import 'package:flutter/material.dart';
import 'package:yaman/widget/variable.dart';
import 'package:yaman/services/storage_service.dart';
import 'package:yaman/services/sync_queue_service.dart';
import 'package:yaman/services/connectivity_service.dart';
import 'package:yaman/services/prayer_service.dart';
import 'package:yaman/students/StudentInterface.dart';
import 'package:yaman/dashboard/dashboard.dart';
import 'package:yaman/Screen/teacherinterface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  String _loadingMessage = 'جاري التحميل...';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    // Start initialization immediately
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final storage = StorageService();
    final connectivity = ConnectivityService();
    final prayerService = PrayerService();

    try {
      // 1. Initialize infra
      await connectivity.initialize();
      await SyncQueueService().initialize();

      // 2. Initial Data Load (Background)
      setState(() => _loadingMessage = 'جاري مزامنة البيانات...');

      // Load local data first to be fast
      // (Supabase sync happens internally in StorageService based on connectivity)
      // We trigger load to ensure cache is populated
      final students = await storage.loadStudents(forceRefresh: true);
      await storage.loadTeachers(forceRefresh: true);
      // Force sync pushed to background to not block UI too long
      storage.forceSync().catchError((e) {
        print('Background force sync failed: $e');
      });

      // 4. Auto-Login Check
      setState(() => _loadingMessage = 'جاري التحقق من تسجيل الدخول...');
      await _checkAutoLogin();
    } catch (e) {
      print('Initialization error: $e');
      // If error, just go to welcome screen after a delay
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/welscreen');
      }
    }
  }

  Future<void> _checkAutoLogin() async {
    // Artificial delay to ensure splash is seen for at least a moment (optional)
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('currentUserRole');
    final userId = prefs.getString('currentUserId');
    final email = prefs.getString('currentUserEmail');

    if (role != null && userId != null) {
      final storage = StorageService();

      try {
        if (role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => Dashboard()),
          );
        } else if (role == 'student') {
          // We need full student object
          final students = await storage.loadStudents();
          final student = students.firstWhere(
            (s) => s.id == userId,
            orElse: () => throw Exception('Student not found'),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => StudentInterface(student: student),
            ),
          );
        } else if (role == 'teacher') {
          // We need full teacher object
          // userId for teacher might be stored as teacherId or name in some contexts,
          // checking SigninScreen logic: it used t.email to find.
          // SigninScreen stored: result['teacherId'] ?? result['role'] (which might be name or id)
          // But checking SigninScreen again:
          // final Teacher teacher = teachers.firstWhere((t) => t.email == emailController.text.trim());
          // So finding by EMAIL is safer if we stored it.

          final teachers = await storage.loadTeachers();
          final teacher = teachers.firstWhere(
            (t) => t.email.toLowerCase() == email!.toLowerCase(), // Use email if available
            orElse: () => throw Exception('Teacher not found'),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TeacherInterface(teacher: teacher),
            ),
          );
        } else {
          Navigator.pushReplacementNamed(context, '/welscreen');
        }
        return;
      } catch (e) {
        print('Auto-login failed: $e');
        // If user not found (deleted?), clear prefs and go to login
        await prefs.clear();
        if (mounted) Navigator.pushReplacementNamed(context, '/welscreen');
      }
    } else {
      Navigator.pushReplacementNamed(context, '/welscreen');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backcolor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _fadeIn,
              child: SizedBox(
                height: 180,
                child: Image.asset('assets/image/logomosque.png'),
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 12),
            Text(_loadingMessage, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
