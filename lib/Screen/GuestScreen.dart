import 'package:flutter/material.dart';
import 'package:yaman/widget/variable.dart';
import 'package:yaman/widget/app_footer.dart';

class GuestScreen extends StatelessWidget {
  const GuestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backcolor,
      appBar: AppBar(
        title: const Text(
          "معلومات المشروع",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              backcolor,
              textcolor.withAlpha(200),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Image/Logo
                Center(
                  child: Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                    //   shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Image.asset(
                          'assets/image/logomosque.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                
                // Info Cards - Using premium aesthetic
                _buildInfoCard(
                  title: "عن التطبيق",
                  content: "تطبيق العمري هو نظام تعليمي متكامل يهدف إلى تسهيل إدارة الحلقات التعليمية ومتابعة أداء الطلاب في الحفظ والعبادات.",
                  icon: Icons.info_outline,
                ),
                const SizedBox(height: 20),
                
                _buildInfoCard(
                  title: "رؤيتنا",
                  content: "الارتقاء بالعملية التعليمية في المساجد باستخدام أحدث الوسائل التقنية لضمان دقة المتابعة وتحفيز الطلاب.",
                  icon: Icons.lightbulb_outline,
                ),
                const SizedBox(height: 20),
                
                _buildInfoCard(
                  title: "المميزات",
                  content: "• متابعة الصلاة والعبادات\n• سجلات الحفظ والتسميع\n• نظام نقاط وجوائز تحفيزي\n• تواصل مباشر بين الأساتذة والطلاب",
                  icon: Icons.star_border,
                ),
                const SizedBox(height: 20),
                
                _buildInfoCard(
                  title: "تواصل معنا",
                  content: "للملاحظات والاقتراحات يرجى التواصل مع إدارة المسجد عبر الأرقام المعتمدة.",
                  icon: Icons.contact_support_outlined,
                ),
                
                const SizedBox(height: 30),
                  const AppFooter(),
                // version info
                const Center(
                  child: Text(
                    "الإصدار 1.0 (تجريبي)",
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required String content, required IconData icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: regsin, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
