import 'dart:math' as math;

import '../constants/app_constants.dart';

enum BmiCategory {
  underweight('Bajo peso'),
  normal('Peso normal'),
  overweight('Sobrepeso'),
  obese('Obesidad');

  const BmiCategory(this.label);
  final String label;
}

/// Fórmulas de fitness: zancada, calorías (MET) e IMC.
class FitnessCalculator {
  FitnessCalculator._();

  // ---------- Zancada y distancia por pasos ----------

  /// Zancada en metros ≈ 41.5 % de la estatura.
  static double strideMeters(double heightCm) =>
      heightCm / 100.0 * AppConstants.strideFactor;

  static double stepsToMeters(int steps, double heightCm) =>
      steps * strideMeters(heightCm);

  // ---------- Calorías ----------

  /// kcal = MET × peso(kg) × horas.
  static double calories({
    required double weightKg,
    required double met,
    required Duration duration,
  }) =>
      met * weightKg * (duration.inMilliseconds / 3600000.0);

  static double averageSpeedMs(double meters, Duration duration) {
    final s = duration.inMilliseconds / 1000.0;
    return s <= 0 ? 0 : meters / s;
  }

  // ---------- Meta diaria ----------

  static double goalProgress(int steps, int goal) {
    if (goal <= 0) return 0;
    return math.min(1.0, steps / goal);
  }

  // ---------- IMC ----------

  /// Rango de la barra de colores.
  static const double bmiScaleMin = 15.0;
  static const double bmiScaleMax = 40.0;

  /// Cortes entre categorías.
  static const double bmiUnderweightMax = 18.5;
  static const double bmiNormalMax = 25.0;
  static const double bmiOverweightMax = 30.0;

  static double bmi(double weightKg, double heightCm) {
    final m = heightCm / 100.0;
    return weightKg / (m * m);
  }

  static BmiCategory bmiCategory(double bmi) {
    if (bmi < bmiUnderweightMax) return BmiCategory.underweight;
    if (bmi < bmiNormalMax) return BmiCategory.normal;
    if (bmi < bmiOverweightMax) return BmiCategory.overweight;
    return BmiCategory.obese;
  }

  /// Peso saludable (IMC 18.5 a 24.9) para una estatura dada.
  static ({double min, double max}) healthyWeightRange(double heightCm) {
    final m = heightCm / 100.0;
    return (min: 18.5 * m * m, max: 24.9 * m * m);
  }

  /// Posición del indicador sobre la barra: 0.0 a 1.0.
  static double bmiGaugePosition(double bmi) {
    final p = (bmi - bmiScaleMin) / (bmiScaleMax - bmiScaleMin);
    return math.max(0.0, math.min(1.0, p));
  }

  /// Posición (0 a 1) de un corte de categoría sobre la barra.
  static double bmiCutPosition(double cut) => bmiGaugePosition(cut);
}