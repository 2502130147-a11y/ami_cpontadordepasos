import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../../app/theme/palette.dart';
import '../logic/effort.dart';

extension EffortStyle on Effort {
  IconData get icon => switch (this) {
        Effort.rest => Icons.self_improvement_rounded,
        Effort.walk => Icons.directions_walk_rounded,
        Effort.jog => Icons.directions_run_rounded,
      };

  Color get color => switch (this) {
        Effort.rest => Palette.lilac,
        Effort.walk => Palette.orchid,
        Effort.jog => Palette.purple,
      };
}

/// Selector visual de 3 segmentos: el activo se ilumina.
class EffortTrack extends StatelessWidget {
  const EffortTrack({super.key, required this.current, this.estimated = false});

  final Effort current;
  final bool estimated;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Palette.lilacSoft,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        children: [
          for (final e in Effort.values)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: e == current
                      ? LinearGradient(colors: [e.color, Palette.violet])
                      : null,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(e.icon, size: 18, color: e == current ? Colors.white : Palette.inkMuted),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        e.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: e == current ? Colors.white : Palette.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Barras centradas para X, Y, Z (valores negativos a la izquierda).
class AxisBars extends StatelessWidget {
  const AxisBars({super.key, required this.x, required this.y, required this.z, this.range = 20, this.unit = 'm/s²'});

  final double x;
  final double y;
  final double z;
  final double range;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row('X', x, Palette.orchid),
        const SizedBox(height: 8),
        _row('Y', y, Palette.violet),
        const SizedBox(height: 8),
        _row('Z', z, Palette.plum),
      ],
    );
  }

  Widget _row(String label, double v, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: color)),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final half = w / 2;
              final bw = (v.abs() / range).clamp(0.0, 1.0) * half;
              return SizedBox(
                height: 12,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Palette.lilacSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    Positioned(
                      left: v >= 0 ? half : half - bw,
                      width: bw,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    Positioned(
                      left: half - 1,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 2, color: Palette.lilacLine),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SizedBox(
          width: 64,
          child: Text(
            v.toStringAsFixed(2),
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
          ),
        ),
      ],
    );
  }
}

/// Brújula del giroscopio: la aguja gira con la orientación integrada.
class GyroDial extends StatelessWidget {
  const GyroDial({super.key, required this.headingDeg, required this.angularDeg, this.size = 130});

  final double headingDeg;
  final double angularDeg;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DialPainter(headingDeg),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                angularDeg.toStringAsFixed(0),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Palette.plum),
              ),
              const Text('°/s', style: TextStyle(fontSize: 11, color: Palette.inkMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter(this.heading);
  final double heading;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = Palette.lilacSoft);
    canvas.drawCircle(
      c,
      r - 6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Palette.lilacLine,
    );
    final tick = Paint()
      ..color = Palette.orchid
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final o = c + Offset(math.cos(a), math.sin(a)) * (r - 8);
      final inn = c + Offset(math.cos(a), math.sin(a)) * (r - (i % 3 == 0 ? 18 : 13));
      canvas.drawLine(inn, o, tick);
    }
    // Aguja
    final a = (heading - 90) * math.pi / 180;
    final tip = c + Offset(math.cos(a), math.sin(a)) * (r - 22);
    canvas.drawLine(
      c + Offset(math.cos(a), math.sin(a)) * (r * 0.42),
      tip,
      Paint()
        ..color = Palette.purple
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(tip, 5, Paint()..color = Palette.purple);
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) => old.heading != heading;
}

/// Nivel de burbuja: muestra la inclinación (cabeceo y alabeo).
class TiltBubble extends StatelessWidget {
  const TiltBubble({super.key, required this.pitch, required this.roll, this.size = 130});

  final double pitch;
  final double roll;
  final double size;

  @override
  Widget build(BuildContext context) {
    final r = size / 2 - 14;
    // Con el teléfono vertical el alabeo ronda 90°: se centra en ese valor.
    final dx = (pitch / 45).clamp(-1.0, 1.0) * r;
    final dy = ((roll.abs() - 90) / 45).clamp(-1.0, 1.0) * r;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Palette.lilacSoft,
              border: Border.all(color: Palette.lilacLine, width: 2),
            ),
          ),
          Container(
            width: size * 0.42,
            height: size * 0.42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Palette.lilacLine, width: 1.5),
            ),
          ),
          AnimatedSlide(
            duration: const Duration(milliseconds: 180),
            offset: Offset(dx / 28, dy / 28),
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: Palette.button,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón que hay que mantener presionado para terminar (evita toques accidentales).
class HoldToFinish extends StatefulWidget {
  const HoldToFinish({super.key, required this.onFinished, this.size = 72});

  final VoidCallback onFinished;
  final double size;

  @override
  State<HoldToFinish> createState() => _HoldToFinishState();
}

class _HoldToFinishState extends State<HoldToFinish> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _c.reset();
        widget.onFinished();
      }
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) {
        if (_c.status != AnimationStatus.completed) _c.reverse();
      },
      onTapCancel: () {
        if (_c.status != AnimationStatus.completed) _c.reverse();
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: CircularProgressIndicator(
                  value: _c.value,
                  strokeWidth: 5,
                  color: Palette.danger,
                  backgroundColor: Palette.lilacSoft,
                ),
              ),
              Container(
                width: widget.size - 16,
                height: widget.size - 16,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Palette.plum),
                child: const Icon(Icons.stop_rounded, color: Colors.white, size: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
