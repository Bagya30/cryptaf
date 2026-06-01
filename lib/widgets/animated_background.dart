import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with TickerProviderStateMixin {
  late AnimationController _c1;
  late AnimationController _c2;
  late AnimationController _c3;

  @override
  void initState() {
    super.initState();
    _c1 = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();
    _c2 = AnimationController(vsync: this, duration: const Duration(seconds: 11))..repeat();
    _c3 = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A0A),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_c1, _c2, _c3]),
              builder: (context, child) {
                return CustomPaint(
                  painter: _AuroraPainter(_c1.value, _c2.value, _c3.value),
                );
              },
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double v1;
  final double v2;
  final double v3;

  _AuroraPainter(this.v1, this.v2, this.v3);

  @override
  void paint(Canvas canvas, Size size) {
    void drawOrb(double val, double radius, Color color, double speedX, double speedY, double offsetX, double offsetY) {
      final center = Offset(
        size.width * offsetX + sin(val * 2 * pi * speedX) * size.width * 0.3,
        size.height * offsetY + cos(val * 2 * pi * speedY) * size.height * 0.3,
      );
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color, color.withOpacity(0)],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    // Orb 1: Gold - top left
    drawOrb(v1, 220, const Color.fromRGBO(212, 168, 83, 0.10), 1.0, 1.0, 0.3, 0.3);
    // Orb 2: Cyan - bottom right
    drawOrb(v2, 180, const Color.fromRGBO(6, 182, 212, 0.10), 1.0, -1.0, 0.7, 0.7);
    // Orb 3: Purple - middle right
    drawOrb(v3, 160, const Color.fromRGBO(168, 85, 247, 0.09), -1.0, 1.0, 0.8, 0.5);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => true;
}

