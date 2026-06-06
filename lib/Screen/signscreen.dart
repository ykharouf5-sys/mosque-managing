import 'package:flutter/material.dart';
import 'package:yaman/models/student.dart';
import 'package:yaman/models/teacher.dart';
import 'package:yaman/widget/My_button.dart';
import 'package:yaman/widget/text_field.dart';
import 'package:yaman/services/storage_service.dart';
import 'package:yaman/dashboard/dashboard.dart';
import 'package:yaman/students/StudentInterface.dart';
import 'package:yaman/Screen/teacherinterface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaman/utils/responsive_helper.dart';
import 'package:yaman/widget/app_footer.dart';


class SignScreen extends StatefulWidget {
  const SignScreen({super.key});

  @override
  State<SignScreen> createState() => _SignScreenState();
}

final Color backcolor = Color.fromARGB(255, 47, 78, 62);
final Color regsin = Color.fromARGB(255, 214, 182, 0);
final Color textcolor = Color.fromARGB(255, 55, 111, 82);
final Color icons = Colors.white;

class _SignScreenState extends State<SignScreen> {
  // Use TextEditingController for robust state management
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final StorageService _storageService = StorageService();

  // Dispose controllers when the widget is removed from the tree
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    
    // Local theme colors
    final Color localBackColor = const Color.fromARGB(255, 47, 78, 62);
    final Color localRegsin = const Color.fromARGB(255, 214, 182, 0);
    final Color localTextColor = const Color.fromARGB(255, 55, 111, 82);

    return Scaffold(
      backgroundColor: localBackColor,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  localBackColor,
                  localBackColor.withOpacity(0.9),
                  localTextColor.withOpacity(0.4),
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    
                    // Logo
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Image.asset(
                        "assets/image/logomosque.png",
                        height: 120,
                        width: 120,
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Welcome Back Text
                    const Text(
                      "أهلاً بك مجدداً",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "سجل دخولك للمتابعة",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    
                    const SizedBox(height: 50),
                    
                    // Glassmorphic Input Section
                    Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          // Email Field
                          _buildModernTextField(
                            controller: _emailController,
                            hint: "البريد الإلكتروني",
                            icon: Icons.email_outlined,
                            isPassword: false,
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Password Field
                          _buildModernTextField(
                            controller: _passwordController,
                            hint: "كلمة المرور",
                            icon: Icons.lock_outline,
                            isPassword: true,
                          ),
                          
                          const SizedBox(height: 35),
                          
                          // Login Button
                          GestureDetector(
                            onTap: () async {
                              final email = _emailController.text.trim();
                              final password = _passwordController.text.trim();

                              if (email.isEmpty || password.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('يرجى إدخال جميع البيانات')),
                                );
                                return;
                              }

                              try {
                                final result = await _storageService.loginUser(email, password);

                                if (result != null) {
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setString('currentUserRole', result['role']);
                                  
                                  final userId = result['studentId'] ?? result['teacherId'] ?? result['adminId'] ?? email;
                                  await prefs.setString('currentUserId', userId);
                                  
                                  if (result['role'] == 'admin') {
                                    await prefs.setString('currentUserName', 'مشرف');
                                  }
                                  await prefs.setString('currentUserEmail', email);

                                  if (result['role'] == 'student') {
                                    Student? foundStudent;
                                    int attempts = 0;
                                    while (attempts < 2 && foundStudent == null) {
                                      attempts++;
                                      try {
                                        final students = await _storageService.loadStudents(forceRefresh: attempts > 1);
                                        foundStudent = students.firstWhere(
                                          (s) => s.id == result['studentId'],
                                          orElse: () => throw Exception('Student not found'),
                                        );
                                      } catch (e) {
                                        if (attempts == 1) await Future.delayed(const Duration(seconds: 1));
                                      }
                                    }
                                    
                                    if (foundStudent != null) {
                                      await prefs.setString('currentUserName', foundStudent.name);
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(builder: (_) => StudentInterface(student: foundStudent!)),
                                      );
                                    } else {
                                      throw Exception('تعذّر تحميل بيانات الطالب بعد المحاولة.');
                                    }
                                  } else if (result['role'] == 'teacher') {
                                    Teacher? foundTeacher;
                                    int attempts = 0;
                                    while (attempts < 2 && foundTeacher == null) {
                                      attempts++;
                                      try {
                                        final teachers = await _storageService.loadTeachers(forceRefresh: attempts > 1);
                                        foundTeacher = teachers.firstWhere(
                                          (t) => t.email.toLowerCase() == email.toLowerCase() || (result['teacherId'] != null && t.id == result['teacherId']),
                                          orElse: () => throw Exception('Teacher not found'),
                                        );
                                      } catch (e) {
                                        if (attempts == 1) await Future.delayed(const Duration(seconds: 1));
                                      }
                                    }

                                    if (foundTeacher != null) {
                                      await prefs.setString('currentUserName', foundTeacher.name);
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(builder: (_) => TeacherInterface(teacher: foundTeacher!)),
                                      );
                                    } else {
                                      throw Exception('تعذّر تحميل بيانات الأستاذ بعد المحاولة.');
                                    }
                                  } else {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (_) => Dashboard()),
                                    );
                                  }

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تم تسجيل الدخول بنجاح!')),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('خطأ في البريد أو كلمة المرور')),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('خطأ: $e')),
                                );
                              }
                            },
                            child: Container(
                              height: 60,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: localRegsin,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: localRegsin.withOpacity(0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  "دخول",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Create Account Link
                   
                    
                    const SizedBox(height: 20),
                    const AppFooter(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isPassword,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(icon, color: Colors.white70),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }
}
