import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:yaman/services/storage_service.dart';
import 'package:yaman/widget/variable.dart';
import 'package:yaman/Screen/gifts_screen.dart';
import 'package:yaman/Screen/AdminChatScreen.dart';
import 'package:yaman/dashboard/adhkar_management.dart';
import 'package:yaman/dashboard/lesson_management.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yaman/widget/responsive_helper.dart';
import 'package:yaman/widget/app_footer.dart';

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  @override
  Widget build(BuildContext context) {
    ResponsiveHelper().init(context);

    return SafeArea(
      bottom: true,
      top: false,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminChatScreen()),
                );
              },
              icon: const Icon(Icons.message, size: 27, color: Colors.white),
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                try {
                  await StorageService().logout();
                } catch (e) {
                  print('Logout error: $e');
                }
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/signscreen',
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [backcolor, textcolor.withValues(alpha: 0.8)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Column(
                children: [
                  // Logo & Header
                  Hero(
                    tag: 'logo',
                    child: Container(
                      width: ResponsiveHelper.w(25),
                      height: ResponsiveHelper.w(25),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.1),
                            blurRadius: 25,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Image.asset("assets/image/logomosque.png"),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "مرحبا بك في رواد مسجد العمري",
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "نظام إدارة الحلقات في تحفيظ القران",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Admin Modules
                  _buildDashboardCard(
                    context: context,
                    icon: Icons.manage_accounts_rounded,
                    title: "إدارة الأساتذة",
                    subtitle: "إضافة أساتذة جدد وتعديل معلوماتهم",
                    btnText: "فتح الإدارة",
                    onTap: () => Navigator.pushNamed(context, "/teacher"),
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(height: 16),
                  _buildDashboardCard(
                    context: context,
                    icon: Icons.people_alt_rounded,
                    title: "إدارة الطلاب",
                    subtitle: "تسجيل الطلاب وتحديث بياناتهم وربطهم بالحلقات",
                    btnText: "إدارة الطلاب",
                    onTap: () => Navigator.pushNamed(context, "/students"),
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(height: 16),
                  _buildDashboardCard(
                    context: context,
                    icon: Icons.event_available_rounded,
                    title: "تسجيل الحضور والغياب",
                    subtitle: "متابعة حضور جميع الطلاب في كافة الحلقات",
                    btnText: "تسجيل الحضور",
                    onTap: () => Navigator.pushNamed(context, "/track"),
                    color: Colors.greenAccent,
                  ),
                  const SizedBox(height: 16),
                  _buildDashboardCard(
                    context: context,
                    icon: Icons.military_tech_rounded,
                    title: " النقاط والمكافآت",
                    subtitle: "منح النقاط ومتابعة لوحة الشرف لجميع الحلقات",
                    btnText: "إضافة نقاط",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GiftsScreen()),
                    ),
                    color: Colors.purpleAccent,
                  ),

                  _buildDashboardCard(
                    context: context,
                    icon: Icons.auto_stories_rounded,
                    title: "إدارة الدروس",
                    subtitle: "إضافة روابط دروس ومراجع للطلاب",
                    btnText: "إدارة الدروس",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LessonManagement()),
                    ),
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 16),
                  _buildDashboardCard(
                    context: context,
                    icon: Icons.mosque_rounded,
                    title: "إدارة الأذكار والأحاديث",
                    subtitle: "إضافة وتعديل أدعية وأذكار للطلاب",
                    btnText: "إدارة الأذكار",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdhkarManagement()),
                    ),
                    color: Colors.tealAccent,
                  ),
                  const SizedBox(height: 10),
                  const AppFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String btnText,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                title,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 30),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: regsin,
                foregroundColor: Colors.white,
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                btnText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
