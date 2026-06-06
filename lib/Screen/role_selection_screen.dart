import 'package:flutter/material.dart';
import 'package:yaman/models/student.dart';
import 'package:yaman/models/teacher.dart';
import 'package:yaman/students/StudentInterface.dart';
import 'package:yaman/Screen/teacherinterface.dart';
import 'package:yaman/widget/variable.dart';
import 'package:yaman/widget/My_button.dart';
import 'package:yaman/widget/app_footer.dart';

import 'package:yaman/Screen/GuestScreen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backcolor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              backcolor,
              backcolor.withOpacity(0.9),
              textcolor.withOpacity(0.4),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo at the top
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Image.asset(
                      'assets/image/logomosque.png',
                      height: 140,
                      width: 140,
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  const Text(
                    "اختر صفتك للدخول",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "يرجى تحديد الدور الخاص بك للمتابعة",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 50),
                  
                  // Role Buttons
                  _buildRoleButton(
                    context,
                    title: "أنا طالب",
                    subtitle: "لمتابعة الحفظ والدرجات",
                    icon: Icons.school_outlined,
                    color: regsin,
                    onTap: () {
                      final trialStudent = Student(
                        id: 'trial_student',
                        name: 'طالب تجريبي',
                        phone: '0000000000',
                        teacherName: 'أستاذ تجريبي',
                        teacherPhone: '0000000000',
                        email: 'trial@student.com',
                        password: 'trial',
                        points: 150,
                        attendance: [true, true, false, true, true],
                        attendanceDates: ['2025-12-20', '2025-12-21', '2025-12-22', '2025-12-23', '2025-12-24'],
                        prayers: [
                          ['جماعة', 'أداء', 'أداء', 'جماعة', 'أداء'],
                          ['أداء', 'أداء', 'أداء', 'أداء', 'أداء'],
                          ['غياب', 'غياب', 'غياب', 'غياب', 'غياب'],
                          ['أداء', 'أداء', 'أداء', 'أداء', 'أداء'],
                          ['جماعة', 'جماعة', 'جماعة', 'جماعة', 'جماعة'],
                        ],
                        prayerDates: ['2025-12-20', '2025-12-21', '2025-12-22', '2025-12-23', '2025-12-24'],
                        memorization: ['ممتاز', 'جيد جداً', 'غائب', 'ممتاز', 'ممتاز'],
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentInterface(student: trialStudent),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  
                  _buildRoleButton(
                    context,
                    title: "أنا أستاذ",
                    subtitle: "لإدارة الطلاب والحلقات",
                    icon: Icons.person_outline,
                    color: textcolor.withOpacity(0.8),
                    onTap: () {
                      final trialTeacher = Teacher(
                        id: 'trial_teacher',
                        name: 'أستاذ تجريبي',
                        number: '0000000000',
                        email: 'trial@teacher.com',
                        password: 'trial',
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TeacherInterface(teacher: trialTeacher),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Guest Button
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const GuestScreen()),
                      );
                    },
                    icon: const Icon(Icons.visibility_outlined, color: Colors.white, size: 20),
                    label: const Text(
                      "استمرار كضيف",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                      ),

                    ),
                  ),
                                    const AppFooter(),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 85,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }
}
