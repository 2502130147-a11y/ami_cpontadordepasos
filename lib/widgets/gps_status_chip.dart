import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../providers/workout_provider.dart';

/// Chip de estado del GPS: "GPS · N pts", "Buscando…" o "GPS apagado".
/// Si se pasa [onTap], el chip es pulsable (por ejemplo, para reintentar).
class GpsStatusChip extends StatelessWidget {
  const GpsStatusChip({
    super.key,
    required this.status,
    required this.label,
    this.onTap,
  });

  final GpsStatus status;
  final String label;
  final VoidCallback? onTap;

  Color get _color {
    switch (status) {
      case GpsStatus.off:
        return AppColors.danger;
      case GpsStatus.searching:
        return AppColors.warning;
      case GpsStatus.active:
        return AppColors.success;
    }
  }

  IconData get _icon {
    switch (status) {
      case GpsStatus.off:
        return Icons.gps_off_rounded;
      case GpsStatus.searching:
        return Icons.gps_not_fixed_rounded;
      case GpsStatus.active:
        return Icons.gps_fixed_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Material(
      color: color.withValues(alpha: 0.18),
      shape: StadiumBorder(
        side: BorderSide(color: color.withValues(alpha: 0.55)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}