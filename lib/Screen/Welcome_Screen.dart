import 'package:flutter/material.dart';
import 'package:yaman/Screen/regestration_Screen.dart'; // Still needed for backcolor if not redefined
import 'package:yaman/widget/My_button.dart';
import 'package:yaman/widget/responsive_helper.dart';
import 'package:yaman/widget/app_footer.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveHelper().init(context);
    
    // Local theme colors to ensure consistency
    final Color localBackColor = const Color.fromARGB(255, 47, 78, 62);
    final Color localRegsin = const Color.fromARGB(255, 214, 182, 0);
    final Color localTextColor = const Color.fromARGB(255, 55, 111, 82);

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  localBackColor,
                  localBackColor.withOpacity(0.9),
                  localTextColor.withOpacity(0.4),
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: ResponsiveHelper.w(8)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 2),
                  
                  // Animated Logo
                  FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideUp,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            height: ResponsiveHelper.h(20),
                            child: Image.asset("assets/image/logomosque.png"),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Title
                  FadeTransition(
                    opacity: _fadeIn,
                    child: SlideTransition(
                      position: _slideUp,
                      child: Column(
                        children: [
                          Text(
                            "مرحباً بك في",
                            style: TextStyle(
                              fontSize: ResponsiveHelper.sp(20),
                              color: Colors.white70,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "رواد مسجد العمري",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: ResponsiveHelper.sp(32),
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  offset: const Offset(0, 4),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const Spacer(flex: 3),
                  
                  // Buttons Section
                  FadeTransition(
                    opacity: _fadeIn,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Login Button
                        _buildGlassButton(
                          context,
                          title: "تسجيل الدخول",
                          color: localRegsin,
                          onPressed: () => Navigator.pushNamed(context, "/signscreen"),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Guest Button
                        _buildGlassButton(
                          context,
                          title: "دخول كضيف",
                          color: Colors.white.withOpacity(0.1),
                          textColor: Colors.white,
                          isOutlined: true,
                          onPressed: () => Navigator.pushNamed(context, "/role_selection"),
                        ),
                        
                        const SizedBox(height: 15),
                        
                      
                      ],
                    ),
                  ),
                  
                  const Spacer(flex: 1),
                  
                  // Footer
                  const AppFooter(),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton(
    BuildContext context, {
    required String title,
    required Color color,
    required VoidCallback onPressed,
    Color textColor = Colors.white,
    bool isOutlined = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: ResponsiveHelper.h(7),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(18),
          border: isOutlined ? Border.all(color: Colors.white24, width: 1.5) : null,
          boxShadow: isOutlined ? [] : [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: ResponsiveHelper.sp(18),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
