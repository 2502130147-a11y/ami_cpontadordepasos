import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/palette.dart';

/// Dos anillos concéntricos: exterior = pasos, interior = kilómetros.
class GoalRings extends StatelessWidget {
  const GoalRings({super.key, required this.outer, required this.inner, this.size = 128, this.child});

  final double outer; // 0..1
  final double inner; // 0..1
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, k, c) => CustomPaint(
        size: Size.square(size),
        painter: _RingsPainter(outer * k, inner * k),
        child: SizedBox.square(dimension: size, child: Center(child: c)),
      ),
      child: child,
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.outer, this.inner);
  final double outer;
  final double inner;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r1 = size.shortestSide / 2 - 8;
    final r2 = r1 - 18;
    _ring(canvas, c, r1, outer, const [Palette.lilac, Colors.white]);
    _ring(canvas, c, r2, inner, const [Palette.orchid, Palette.lilac]);
  }

  void _ring(Canvas canvas, Offset c, double r, double v, List<Color> colors) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = Colors.white.withValues(alpha: 0.14),
    );
    final sweep = 2 * math.pi * v.clamp(0.0, 1.0);
    if (sweep <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * math.pi,
          colors: colors,
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) => old.outer != outer || old.inner != inner;
}
