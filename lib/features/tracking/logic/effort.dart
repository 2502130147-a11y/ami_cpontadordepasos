/// Intensidad del movimiento clasificada con el acelerómetro.
enum Effort {
  rest,
  walk,
  jog;

  // Umbrales sobre la aceleración dinámica suavizada |a| - g (m/s²).
  static const double walkFrom = 0.8;
  static const double jogFrom = 3.5;

  static Effort fromLevel(double v) {
    if (v < walkFrom) return Effort.rest;
    if (v < jogFrom) return Effort.walk;
    return Effort.jog;
  }

  String get label => switch (this) {
        Effort.rest => 'Descanso',
        Effort.walk => 'Caminata',
        Effort.jog => 'Trote',
      };

  /// Equivalente metabólico para estimar calorías.
  double get met => switch (this) {
        Effort.rest => 1.3,
        Effort.walk => 3.5,
        Effort.jog => 8.0,
      };

  /// Valor típico de intensidad (para las gráficas en segundo plano).
  double get typicalLevel => switch (this) {
        Effort.rest => 0.3,
        Effort.walk => 2.0,
        Effort.jog => 4.6,
      };
}
