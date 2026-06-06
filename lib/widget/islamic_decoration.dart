import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:yaman/widget/variable.dart';

class IslamicDecoration extends StatelessWidget {
  const IslamicDecoration({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          // Geometric Islamic patterns
          Positioned(
            top: 50,
            right: -50,
            child: Opacity(
              opacity: 0.1,
              child: CustomPaint(
                size: const Size(200, 200),
                painter: _IslamicPatternPainter(),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -50,
            child: Opacity(
              opacity: 0.08,
              child: CustomPaint(
                size: const Size(180, 180),
                painter: _IslamicPatternPainter(),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.3,
            left: MediaQuery.of(context).size.width * 0.5,
            child: Opacity(
              opacity: 0.06,
              child: CustomPaint(
                size: const Size(150, 150),
                painter: _IslamicPatternPainter(),
              ),
            ),
          ),
          // Crescent moon and star
          Positioned(
            top: 80,
            left: 30,
            child: Opacity(
              opacity: 0.15,
              child: Icon(
                Icons.star,
                size: 40,
                color: regsin,
              ),
            ),
          ),
          Positioned(
            bottom: 150,
            right: 40,
            child: Opacity(
              opacity: 0.12,
              child: Icon(
                Icons.star,
                size: 35,
                color: regsin,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IslamicPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = regsin
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Draw first square (0 degrees)
    _drawSquare(canvas, paint, center, radius, 0);

    // 2. Draw second square (45 degrees)
    _drawSquare(canvas, paint, center, radius, 0.785398); // 45 degrees in radians

    // 3. Draw inner circle decoration
    final circlePaint = Paint()
      ..color = regsin.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.2, circlePaint);
    
    // 4. Draw outer connecting ring (optional complexity)
    final ringPaint = Paint()
      ..color = regsin.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius * 0.7, ringPaint);
  }

  void _drawSquare(Canvas canvas, Paint paint, Offset center, double radius, double rotation) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
        // 90 degrees step
      final angle = rotation + (i * 1.5708);
      final x = center.dx + radius * 0.8 * math.cos(angle);
      final y = center.dy + radius * 0.8 * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



