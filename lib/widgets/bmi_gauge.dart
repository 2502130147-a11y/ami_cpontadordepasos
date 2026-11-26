import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/fitness_calculator.dart';

/// Marcador de IMC: barra azul / verde / naranja / roja con indicador de
/// posición, etiqueta, rango de peso saludable y aviso orientativo.
class BmiGauge extends StatelessWidget {
  const BmiGauge({super.key, required this.bmi, required this.heightCm});

  final double bmi;
  final double heightCm;

  static Color colorFor(BmiCategory category) {
    switch (category) {
      case BmiCategory.underweight:
        return AppColors.bmiUnderweight;
      case BmiCategory.normal:
        return AppColors.bmiNormal;
      case BmiCategory.overweight:
        return AppColors.bmiOverweight;
      case BmiCategory.obese:
        return AppColors.bmiObese;
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = FitnessCalculator.bmiCategory(bmi);
    final color = colorFor(category);
    final position = FitnessCalculator.bmiGaugePosition(bmi);
    final range = FitnessCalculator.healthyWeightRange(heightCm);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              bmi.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'IMC',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final x = (position * w).clamp(0.0, w).toDouble();
            return SizedBox(
              height: 60,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Indicador de posición
                  Positioned(
                    left: x - 12,
                    top: 0,
                    child: Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 24,
                      color: color,
                    ),
                  ),
                  // Barra de colores (anchos proporcionales a cada rango)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 20,
                    height: 14,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 35,
                            child: ColoredBox(color: AppColors.bmiUnderweight),
                          ),
                          Expanded(
                            flex: 65,
                            child: ColoredBox(color: AppColors.bmiNormal),
                          ),
                          Expanded(
                            flex: 50,
                            child: ColoredBox(color: AppColors.bmiOverweight),
                          ),
                          Expanded(
                            flex: 100,
                            child: ColoredBox(color: AppColors.bmiObese),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Números de los cortes
                  for (final cut in const [
                    FitnessCalculator.bmiUnderweightMax,
                    FitnessCalculator.bmiNormalMax,
                    FitnessCalculator.bmiOverweightMax,
                  ])
                    Positioned(
                      left: FitnessCalculator.bmiCutPosition(cut) * w - 16,
                      top: 40,
                      width: 32,
                      child: Text(
                        cut == cut.roundToDouble()
                            ? cut.toStringAsFixed(0)
                            : cut.toStringAsFixed(1),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        const Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _LegendDot(color: AppColors.bmiUnderweight, label: 'Bajo peso'),
            _LegendDot(color: AppColors.bmiNormal, label: 'Normal'),
            _LegendDot(color: AppColors.bmiOverweight, label: 'Sobrepeso'),
            _LegendDot(color: AppColors.bmiObese, label: 'Obesidad'),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.favorite_rounded,
              size: 16,
              color: AppColors.bmiNormal,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Peso saludable para tu estatura: '
                    '${range.min.toStringAsFixed(1)} – '
                    '${range.max.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'El IMC es solo una referencia orientativa y no sustituye la '
              'valoración de un profesional de la salud.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}