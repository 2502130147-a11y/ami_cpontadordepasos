import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../data/models/intensity.dart';

Color intensityColor(Intensity i) {
  switch (i) {
    case Intensity.rest:
      return AppColors.intensityRest;
    case Intensity.walk:
      return AppColors.intensityWalk;
    case Intensity.jog:
      return AppColors.intensityJog;
  }
}

IconData intensityIcon(Intensity i) {
  switch (i) {
    case Intensity.rest:
      return Icons.self_improvement_rounded;
    case Intensity.walk:
      return Icons.directions_walk_rounded;
    case Intensity.jog:
      return Icons.directions_run_rounded;
  }
}

/// Clasificación actual (descanso / caminata / trote) con barra de nivel y
/// tiempo acumulado por intensidad.
class IntensityBar extends StatelessWidget {
  const IntensityBar({
    super.key,
    required this.current,
    required this.rest,
    required this.walk,
    required this.jog,
  });

  final Intensity current;
  final Duration rest;
  final Duration walk;
  final Duration jog;

  Duration _timeOf(Intensity i) {
    switch (i) {
      case Intensity.rest:
        return rest;
      case Intensity.walk:
        return walk;
      case Intensity.jog:
        return jog;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = intensityColor(current);
    final totalMs = rest.inMilliseconds + walk.inMilliseconds + jog.inMilliseconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(intensityIcon(current), color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Intensidad actual',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    current.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Barra de nivel: 3 segmentos, se encienden hasta la intensidad actual.
        Row(
          children: [
            for (final i in Intensity.values)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 12,
                  margin: EdgeInsets.only(right: i.level < 2 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: i.level <= current.level
                        ? intensityColor(i)
                        : intensityColor(i).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Tiempo por intensidad',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        for (final i in Intensity.values)
          _TimeRow(
            intensity: i,
            time: _timeOf(i),
            fraction: totalMs == 0 ? 0 : _timeOf(i).inMilliseconds / totalMs,
          ),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.intensity,
    required this.time,
    required this.fraction,
  });

  final Intensity intensity;
  final Duration time;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final color = intensityColor(intensity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  intensity.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Text(
                Formatters.duration(time),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              SizedBox(
                width: 46,
                child: Text(
                  '${(fraction * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 5,
              color: color,
              backgroundColor: AppColors.surfaceAlt,
            ),
          ),
        ],
      ),
    );
  }
}