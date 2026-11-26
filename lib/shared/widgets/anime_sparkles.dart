import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/palette.dart';

/// Destellos y corazones que parpadean, estilo anime.
/// Se pinta detrás del contenido (no recibe toques).
class AnimeSparkles extends StatefulWidget {
  const AnimeSparkles({
    super.key,
    this.count = 14,
    this.color = Colors.white,
    this.accent = Palette.lilac,
    this.seed = 7,
    this.hearts = true,
  });

  final int count;
  final Color color;
  final Color accent;
  final int seed;
  final bool hearts;

  @override
  State<AnimeSparkles> createState() => _AnimeSparklesState();
}

class _AnimeSparklesState extends State<AnimeSparkles> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  late final List<_Spark> _sparks = _make();

  List<_Spark> _make() {
    final r = math.Random(widget.seed);
    return List.generate(widget.count, (i) {
      return _Spark(
        x: r.nextDouble(),
        y: r.nextDouble(),
        size: 4 + r.nextDouble() * 9,
        phase: r.nextDouble(),
        heart: widget.hearts && i % 4 == 3,
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => CustomPaint(
            size: Size.infinite,
            painter: _SparklePainter(_sparks, _c.value, widget.color, widget.accent),
          ),
        ),
      ),
    );
  }
}

class _Spark {
  const _Spark({required this.x, required this.y, required this.size, required this.phase, required this.heart});
  final double x;
  final double y;
  final double size;
  final double phase;
  final bool heart;
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.sparks, this.t, this.color, this.accent);

  final List<_Spark> sparks;
  final double t;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in sparks) {
      // Brillo que sube y baja (0..1) desfasado por destello.
      final k = 0.5 + 0.5 * math.sin(2 * math.pi * (t + s.phase));
      final c = Offset(s.x * size.width, s.y * size.height);
      final r = s.size * (0.55 + 0.45 * k);
      final paint = Paint()..color = (s.heart ? accent : color).withValues(alpha: 0.25 + 0.6 * k);
      if (s.heart) {
        _heart(canvas, c, r * 0.9, paint);
      } else {
        _star(canvas, c, r, paint);
      }
    }
  }

  /// Estrella de 4 puntas (destello típico del anime).
  void _star(Canvas canvas, Offset c, double r, Paint p) {
    final w = r * 0.28;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + w * 0.4, c.dy - w * 0.4, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + w * 0.4, c.dy + w * 0.4, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - w * 0.4, c.dy + w * 0.4, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - w * 0.4, c.dy - w * 0.4, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, p);
  }

  void _heart(Canvas canvas, Offset c, double r, Paint p) {
    final path = Path()
      ..moveTo(c.dx, c.dy + r * 0.8)
      ..cubicTo(c.dx - r * 1.4, c.dy - r * 0.2, c.dx - r * 0.6, c.dy - r * 1.2, c.dx, c.dy - r * 0.4)
      ..cubicTo(c.dx + r * 0.6, c.dy - r * 1.2, c.dx + r * 1.4, c.dy - r * 0.2, c.dx, c.dy + r * 0.8)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.t != t;
}

/// Avatar circular con la mascota y un aro degradado lila.
class MascotAvatar extends StatelessWidget {
  const MascotAvatar({super.key, this.size = 56, this.ring = true});

  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      Palette.mascotAvatar,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stack) =>
          Icon(Icons.diamond_rounded, color: Palette.lilac, size: size * 0.6),
    );
    if (!ring) return img;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: Palette.lilacButton),
      child: Container(
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Palette.plum),
        child: img,
      ),
    );
  }
}
