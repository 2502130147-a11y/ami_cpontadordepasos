import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../data/models/workout_model.dart';

enum LiveChartKind { speed, intensity }

/// Gráfica de velocidad (km/h) o de intensidad (0 a 2) contra el tiempo.
/// Sirve para el entrenamiento en vivo y para el detalle del historial.
class LiveChart extends StatelessWidget {
  const LiveChart({
    super.key,
    required this.title,
    required this.samples,
    required this.kind,
    this.height = 150,
  });

  final String title;
  final List<ChartSample> samples;
  final LiveChartKind kind;
  final double height;

  bool get _isSpeed => kind == LiveChartKind.speed;

  @override
  Widget build(BuildContext context) {
    final color = _isSpeed ? AppColors.secondary : AppColors.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_isSpeed && samples.isNotEmpty)
              Text(
                '${samples.last.speedKmh.toStringAsFixed(1)} km/h',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: samples.length < 2
              ? const Center(
            child: Text(
              'Esperando datos…',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
              : RepaintBoundary(child: _buildChart(color)),
        ),
      ],
    );
  }

  Widget _buildChart(Color color) {
    final minX = samples.first.second.toDouble();
    final maxX = math.max(samples.last.second.toDouble(), minX + 10);

    final spots = <FlSpot>[
      for (final s in samples)
        FlSpot(
          s.second.toDouble(),
          _isSpeed ? s.speedKmh : s.intensityLevel.toDouble(),
        ),
    ];

    double maxY;
    if (_isSpeed) {
      final peak = samples.fold<double>(0, (m, s) => math.max(m, s.speedKmh));
      maxY = math.max(6.0, peak * 1.2);
    } else {
      maxY = 2;
    }
    final yInterval = _isSpeed ? maxY / 4 : 1.0;

    const hidden = AxisTitles(sideTitles: SideTitles(showTitles: false));

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: 0,
        maxY: maxY,
        clipData: const FlClipData.all(),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) =>
          const FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: hidden,
          rightTitles: hidden,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: _isSpeed ? 36 : 48,
              interval: yInterval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  _leftLabel(value, maxY),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (maxX - minX) / 3,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  Formatters.duration(Duration(seconds: value.round())),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: _isSpeed,
            curveSmoothness: 0.2,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  String _leftLabel(double value, double maxY) {
    if (_isSpeed) {
      return value.toStringAsFixed(maxY < 10 ? 1 : 0);
    }
    switch (value.round()) {
      case 0:
        return 'Desc.';
      case 1:
        return 'Cam.';
      case 2:
        return 'Trote';
      default:
        return '';
    }
  }
}