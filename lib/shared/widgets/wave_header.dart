import 'package:flutter/material.dart';

import '../../app/theme/palette.dart';
import 'anime_sparkles.dart';

/// Encabezado morado con borde inferior en forma de ola.
class WaveHeader extends StatelessWidget {
  const WaveHeader({
    super.key,
    required this.child,
    this.bottomSpace = 56,
    this.gradient = Palette.hero,
  });

  final Widget child;
  final double bottomSpace;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ClipPath(
      clipper: _WaveClipper(),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: gradient),
        padding: EdgeInsets.fromLTRB(22, top + 14, 22, bottomSpace),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Burbujas decorativas
            Positioned(
              right: -40,
              top: -30,
              child: _Bubble(size: 150, alpha: 0.10),
            ),
            Positioned(
              left: -30,
              bottom: -50,
              child: _Bubble(size: 110, alpha: 0.07),
            ),
            const Positioned.fill(child: AnimeSparkles(count: 16)),
            child,
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.alpha});
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final h = size.height;
    final w = size.width;
    return Path()
      ..lineTo(0, h - 34)
      ..quadraticBezierTo(w * 0.22, h + 6, w * 0.52, h - 22)
      ..quadraticBezierTo(w * 0.80, h - 48, w, h - 14)
      ..lineTo(w, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
