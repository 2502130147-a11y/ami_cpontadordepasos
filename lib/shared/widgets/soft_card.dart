import 'package:flutter/material.dart';

import '../../app/theme/palette.dart';

/// Tarjeta blanca de esquinas muy redondeadas con sombra lila difusa.
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = Colors.white,
    this.gradient,
    this.onTap,
    this.radius = 26,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: br,
        boxShadow: [
          BoxShadow(
            color: Palette.purple.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: br,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Círculo con degradado y un ícono al centro.
class IconBadge extends StatelessWidget {
  const IconBadge(
    this.icon, {
    super.key,
    this.size = 44,
    this.gradient = Palette.lilacButton,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final double size;
  final Gradient gradient;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradient),
      child: Icon(icon, color: iconColor, size: size * 0.5),
    );
  }
}

/// Título de sección con acción opcional a la derecha.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 20, color: Palette.orchid),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Palette.ink),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Valor grande + etiqueta, usado en tarjetas de métricas.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.unit,
    this.dark = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? unit;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : Palette.ink;
    final muted = dark ? Palette.lilacSoft : Palette.inkMuted;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: dark ? Colors.white.withValues(alpha: 0.18) : Palette.lilacSoft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: dark ? Palette.lilac : Palette.violet),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: fg),
                children: [
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
