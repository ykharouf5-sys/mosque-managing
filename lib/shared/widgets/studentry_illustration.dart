import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A local, offline illustration. Animation is presentation only.
class StudentryIllustration extends StatefulWidget {
  const StudentryIllustration({
    super.key,
    this.splash = false,
    this.animate = true,
  });

  final bool splash;
  final bool animate;

  @override
  State<StudentryIllustration> createState() => _StudentryIllustrationState();
}

class _StudentryIllustrationState extends State<StudentryIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMotion();
  }

  @override
  void didUpdateWidget(covariant StudentryIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateMotion();
  }

  void _updateMotion() {
    final enabled =
        widget.animate &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (enabled && !_motion.isAnimating) {
      _motion.repeat();
    } else if (!enabled) {
      _motion.stop();
      _motion.value = 0;
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AnimatedBuilder(
      animation: _motion,
      child: Image.asset(
        widget.splash
            ? 'assets/image/studentry_brand_splash.png'
            : 'assets/image/studentry_brand_splash.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      ),
      builder: (context, child) => Transform.translate(
        offset: Offset(0, math.sin(_motion.value * math.pi * 2) * 3),
        child: child,
      ),
    ),
  );
}
