import 'package:flutter/material.dart';
import 'package:yaman/widget/variable.dart' as palette;
import 'package:yaman/widget/islamic_decoration.dart';

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});
  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          // Islamic decoration
          const IslamicDecoration(),
          // Animated blobs
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final v = _controller.value;
              return Stack(
                children: [
                  Positioned(
                    top: 80 + 60 * v,
                    left: -80 + 40 * v,
                    child: _blob(220, [palette.backcolor, palette.textcolor]),
                  ),
                  Positioned(
                    bottom: -60 + 50 * (1 - v),
                    right: -80 + 50 * v,
                    child: _blob(260, [palette.textcolor, palette.regsin]),
                  ),
                  Positioned(
                    top: -40 + 40 * (1 - v),
                    right: -60 + 30 * (1 - v),
                    child: _blob(180, [palette.regsin, palette.textcolor]),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, List<Color> colors) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [colors.first.withValues(alpha: 0.18), colors.last.withValues(alpha: 0.08)],
        ),
        boxShadow: [
          BoxShadow(color: colors.last.withValues(alpha: 0.08), blurRadius: 80, spreadRadius: 20),
        ],
      ),
    );
  }
}
