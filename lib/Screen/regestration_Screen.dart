import 'package:flutter/material.dart';
import 'package:yaman/widget/My_button.dart';
import 'package:yaman/widget/text_field.dart';
import 'package:yaman/services/storage_service.dart';
import 'package:yaman/dashboard/dashboard.dart';
import 'package:yaman/students/StudentInterface.dart';
import 'package:yaman/Screen/teacherinterface.dart';
import 'package:yaman/models/student.dart';
import 'package:yaman/models/teacher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaman/utils/responsive_helper.dart';


class Regestration extends StatefulWidget {
  const Regestration({super.key});

  @override
  State<Regestration> createState() => _RegestrationState();
}

final Color backcolor = Color.fromARGB(255, 47, 78, 62);
final Color regsin = Color.fromARGB(255, 214, 182, 0);
final Color textcolor = Color.fromARGB(255, 55, 111, 82);
final Color icons = Colors.white;

class _RegestrationState extends State<Regestration> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final StorageService _storageService = StorageService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    
    return SafeArea(
      top: false,
      bottom: true,
      child: Scaffold(
        backgroundColor: backcolor,
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: responsive.height(15)),
                SizedBox(
                  height: responsive.width(25),
                  width: responsive.width(25),
                  child: Image.asset("assets/image/logomosque.png"),
                ),
                SizedBox(height: responsive.height(2)),

                // Email field
                AppTextField(
                  colorborder: regsin,
                  hint: "Enter Email",
                  icons: Icon(Icons.email, color: icons),
                  onchanged: (value) {},
                  pass: false, controller: _emailController,
                ),
                SizedBox(height: 10),

                // Password field
                AppTextField(
                  colorborder: regsin,
                  hint: "Enter password",
                  icons: Icon(Icons.password, color: icons),
                  onchanged: (value) {},
                  pass: true, controller: _passwordController,
                ),
                SizedBox(height: responsive.height(2)),

                SizedBox(height: responsive.height(2)),

                Container(
                  margin: EdgeInsets.symmetric(horizontal: responsive.width(5)),
                  child: Center(
                    child: Column(
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, "/signscreen");
                          },
                          child: Text(
                            "تسجيل الدخول بحساب موجود",
                            style: TextStyle(
                              fontSize: responsive.fontSize(16),
                              color: Colors.white,
                            ),
                          ),
                        ),

                        Text(
                          "_______أو_______",
                          style: TextStyle(
                            fontSize: responsive.fontSize(16),
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                MaterialButtonYaman(
                  onPressed: () async {
                    final email = _emailController.text.trim();
                    final password = _passwordController.text.trim();

                    if (email.isEmpty || password.isEmpty) {
                       ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('الرجاء إدخال البريد الإلكتروني وكلمة المرور')),
                       );
                       return;
                    }

                    try {
                      final result = await _storageService.registerUser(
                        email,
                        password,
                        'student',
                      );

                      if (result != null) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('currentUserRole', result['role']);
                        final userId = result['role'] == 'student' 
                            ? result['studentId'] 
                            : result['teacherId'] ?? result['role'];
                        await prefs.setString('currentUserId', userId);
                        await prefs.setString('currentUserEmail', email);

                        // Retry Logic
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
                               if (attempts == 1) await Future.delayed(Duration(seconds: 1));
                             }
                          }

                          if (foundStudent != null) {
                             Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentInterface(student: foundStudent!),
                              ),
                            );
                          } else {
                             throw Exception('تم إنشاء الحساب ولكن فشل تحميل البيانات.');
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
                                  if (attempts == 1) await Future.delayed(Duration(seconds: 1));
                                }
                             }

                             if (foundTeacher != null) {
                               Navigator.pushReplacement(
                                 context,
                                 MaterialPageRoute(
                                   builder: (_) => TeacherInterface(teacher: foundTeacher!),
                                 ),
                               );
                             } else {
                                throw Exception('تم إنشاء الحساب ولكن فشل تحميل بيانات الأستاذ.');
                             }
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => Dashboard()),
                          );
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تم إنشاء الحساب بنجاح!')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('فشل في إنشاء الحساب')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('خطأ: $e')),
                      );
                    }
                  },
                  color: regsin,
                  title: "إنشاء حساب",
                  colorText: Colors.white,
                  height: responsive.height(6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
