import '../../core/constants/app_constants.dart';

/// Intensidad del movimiento: descanso, caminata o trote.
enum Intensity {
  rest('Descanso', 0),
  walk('Caminata', 1),
  jog('Trote', 2);

  const Intensity(this.label, this.level);
  final String label;

  /// 0, 1 o 2. Sirve para graficar la intensidad en el eje Y.
  final int level;

  /// MET (kcal por kg por hora) de esta intensidad.
  double get met {
    switch (this) {
      case Intensity.rest:
        return AppConstants.metRest;
      case Intensity.walk:
        return AppConstants.metWalk;
      case Intensity.jog:
        return AppConstants.metJog;
    }
  }

  /// Clasifica según la desviación de la aceleración respecto a la gravedad.
  static Intensity fromMotion(double deviation) {
    if (deviation < AppConstants.motionRestMax) return Intensity.rest;
    if (deviation < AppConstants.motionWalkMax) return Intensity.walk;
    return Intensity.jog;
  }

  static Intensity fromLevel(int level) {
    return Intensity.values.firstWhere(
          (i) => i.level == level,
      orElse: () => Intensity.rest,
    );
  }
}