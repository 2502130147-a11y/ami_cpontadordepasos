import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/theme/palette.dart';
import '../utils/fmt.dart';

/// Línea suave con área degradada (intensidad, velocidad, aceleración…).
class SeriesChart extends StatelessWidget {
  const SeriesChart({
    super.key,
    required this.values,
    this.color = Palette.purple,
    this.height = 140,
    this.minY = 0,
    this.maxY,
    this.animate = true,
    this.guides = const [],
  });

  final List<double> values;
  final Color color;
  final double height;
  final double minY;
  final double? maxY;
  final bool animate;

  /// Líneas horizontales de referencia (p. ej. umbrales de intensidad).
  final List<double> guides;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('Sin datos suficientes', style: TextStyle(color: Palette.inkMuted)),
        ),
      );
    }
    final spots = [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])];
    final top = maxY ?? math.max(1.0, values.reduce(math.max) * 1.2);
    return SizedBox(
      height: height,
      child: LineChart(
        duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
        LineChartData(
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          minY: minY,
          maxY: top,
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: guides.isNotEmpty,
            drawVerticalLine: false,
            checkToShowHorizontalLine: (v) => guides.any((g) => (g - v).abs() < 1e-6),
            getDrawingHorizontalLine: (_) => const FlLine(
              color: Palette.lilacLine,
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
            horizontalInterval: guides.isEmpty ? null : 0.1,
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barras de pasos por día (lunes..domingo) con fondo de pista.
class WeekBars extends StatelessWidget {
  const WeekBars({super.key, required this.values, this.highlight, this.height = 150});

  final List<int> values; // 7 valores
  final int? highlight; // índice del día actual
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxV = math.max(1000, values.fold<int>(0, math.max)).toDouble() * 1.15;
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxV,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Palette.plum,
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${Fmt.thousands(rod.toY.round())} pasos',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i > 6) return const SizedBox.shrink();
                  final on = i == highlight;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      Fmt.weekLetters[i],
                      style: TextStyle(
                        fontWeight: on ? FontWeight.w900 : FontWeight.w600,
                        color: on ? Palette.purple : Palette.inkMuted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < 7; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i].toDouble(),
                    width: 16,
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: i == highlight
                          ? const [Palette.purple, Palette.orchid]
                          : const [Palette.lilac, Palette.orchid],
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxV,
                      color: Palette.lilacSoft,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Barra horizontal partida en descanso / caminata / trote.
class EffortSplitBar extends StatelessWidget {
  const EffortSplitBar({
    super.key,
    required this.restSec,
    required this.walkSec,
    required this.jogSec,
    this.height = 12,
  });

  final int restSec;
  final int walkSec;
  final int jogSec;
  final double height;

  static const restColor = Palette.lilacLine;
  static const walkColor = Palette.orchid;
  static const jogColor = Palette.purple;

  @override
  Widget build(BuildContext context) {
    final total = restSec + walkSec + jogSec;
    if (total == 0) {
      return Container(
        height: height,
        decoration: BoxDecoration(color: Palette.lilacSoft, borderRadius: BorderRadius.circular(height)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            if (restSec > 0) Expanded(flex: restSec, child: Container(color: restColor)),
            if (walkSec > 0) Expanded(flex: walkSec, child: Container(color: walkColor)),
            if (jogSec > 0) Expanded(flex: jogSec, child: Container(color: jogColor)),
          ],
        ),
      ),
    );
  }
}
