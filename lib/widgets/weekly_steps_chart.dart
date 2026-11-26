import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../data/repositories/workout_repository.dart';

/// Barras de pasos de los últimos 7 días, con línea punteada de la meta.
/// Verde = día que alcanzó la meta; el día de hoy lleva la etiqueta resaltada.
class WeeklyStepsChart extends StatelessWidget {
  const WeeklyStepsChart({
    super.key,
    required this.days,
    required this.goal,
    this.height = 190,
  });

  final List<DailySteps> days;
  final int goal;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'Sin datos todavía',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final peak = days.fold<int>(0, (m, d) => math.max(m, d.steps));
    final maxY = math.max(goal, peak) * 1.15;
    final todayKey = Formatters.dayKey(DateTime.now());

    const hidden = AxisTitles(sideTitles: SideTitles(showTitles: false));

    return SizedBox(
      height: height,
      child: RepaintBoundary(
        child: BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: maxY / 4,
              getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1),
            ),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.surfaceAlt,
                getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                    BarTooltipItem(
                      '${Formatters.integer(rod.toY.round())} pasos',
                      const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: hidden,
              topTitles: hidden,
              rightTitles: hidden,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= days.length) {
                      return const SizedBox.shrink();
                    }
                    final d = days[i].day;
                    final isToday = Formatters.dayKey(d) == todayKey;
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        Formatters.weekdayShort(d),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                          isToday ? FontWeight.w800 : FontWeight.w500,
                          color: isToday
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: goal.toDouble(),
                  color: AppColors.accent.withValues(alpha: 0.85),
                  strokeWidth: 1.5,
                  dashArray: [6, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    labelResolver: (_) => 'Meta',
                  ),
                ),
              ],
            ),
            barGroups: [
              for (var i = 0; i < days.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: days[i].steps.toDouble(),
                      width: 18,
                      color: days[i].steps >= goal
                          ? AppColors.success
                          : AppColors.secondary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY,
                        color: AppColors.surfaceAlt,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}