import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Nivel de burbuja: muestra la inclinación del celular (pitch y roll en
/// grados). Con el celular plano, la burbuja queda al centro y el anillo se
/// pone verde. Se repinta solo cuando cambian los valores.
class TiltIndicator extends StatelessWidget {
  const TiltIndicator({
    super.key,
    required this.pitch,
    required this.roll,
    this.size = 130,
  });

  final double pitch;
  final double roll;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            size: Size.square(size),
            painter: _TiltPainter(pitch: pitch, roll: roll),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Adelante/atrás ${pitch.toStringAsFixed(0)}°',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        Text(
          'Lateral ${roll.toStringAsFixed(0)}°',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _TiltPainter extends CustomPainter {
  _TiltPainter({required this.pitch, required this.roll});

  final double pitch;
  final double roll;

  /// Inclinación (grados) con la que la burbuja llega al borde.
  static const double _maxTilt = 60;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    final isLevel = pitch.abs() < 5 && roll.abs() < 5;
    final ringColor = isLevel ? AppColors.success : AppColors.border;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = AppColors.surfaceAlt,
    );

    final line = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius * 0.5, line);
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      line,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      line,
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = ringColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );

    const bubbleRadius = 12.0;
    final reach = radius - bubbleRadius - 2;
    final dx = (roll / _maxTilt).clamp(-1.0, 1.0).toDouble() * reach;
    final dy = (-pitch / _maxTilt).clamp(-1.0, 1.0).toDouble() * reach;
    final bubble = Offset(center.dx + dx, center.dy + dy);

    canvas.drawCircle(
      bubble,
      bubbleRadius,
      Paint()..color = isLevel ? AppColors.success : AppColors.secondary,
    );
    canvas.drawCircle(
      bubble,
      bubbleRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _TiltPainter old) =>
      old.pitch != pitch || old.roll != roll;
}