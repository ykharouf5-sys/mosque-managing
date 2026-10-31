import 'package:flutter/material.dart';
import 'package:studentry/shared/widgets/studentry_illustration.dart';
import 'package:studentry/utils/variable_colors.dart';

/// Fits the form into the usable viewport, including the keyboard inset.
/// Decorative content collapses before the form scales; no page scrolling.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.compact = false,
    this.showBack = true,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final bool compact;
  final bool showBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFE8F6F7),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
          final short = box.maxHeight < 650 || keyboard;
          final artHeight = keyboard || box.maxHeight < 480
              ? 0.0
              : (box.maxHeight * (compact ? .12 : .20)).clamp(
                  50.0,
                  compact ? 110.0 : 165.0,
                );
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  if (!keyboard && box.maxHeight > 420)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
                      child: SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/image/logo.png',
                              width: 30,
                              height: 30,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Studentry',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ),
                            if (showBack && Navigator.canPop(context))
                              const BackButton(color: AppColors.textDark),
                          ],
                        ),
                      ),
                    ),
                  if (artHeight > 0)
                    SizedBox(
                      height: artHeight,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 4,
                        ),
                        child: StudentryIllustration(),
                      ),
                    ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(
                        short ? 16 : 24,
                        short ? 12 : 22,
                        short ? 16 : 24,
                        short ? 8 : 16,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, panel) => Align(
                          alignment: Alignment.topCenter,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: panel.maxWidth,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: short ? 22 : 26,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDark,
                                      height: 1.4,
                                    ),
                                  ),
                                  if (!keyboard) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF64748B),
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                  SizedBox(height: short ? 10 : 20),
                                  child,
                                  if (footer != null && !keyboard) ...[
                                    const SizedBox(height: 8),
                                    footer!,
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
