/// Constantes globales de FitPulse.
/// Aquí viven los "números mágicos" para ajustarlos desde un solo lugar.
class AppConstants {
  AppConstants._();

  // ---------- Identidad ----------
  static const String appName = 'FitPulse';
  static const String appSubtitle = 'Entrena con datos reales';

  // ---------- Persistencia ----------
  static const String dbName = 'fitpulse.db';
  static const int dbVersion = 1;
  static const String prefBiometricUserId = 'biometric_user_id';
  static const String prefLastUsername = 'last_username';

  // ---------- Notificación del servicio en primer plano ----------
  static const String notificationChannelId = 'fitpulse_workout';
  static const String notificationChannelName = 'Entrenamiento en curso';
  static const int notificationId = 1001;

  // ---------- Validaciones de registro ----------
  static const int nameMinLength = 2;
  static const int nameMaxLength = 40;
  static const int usernameMinLength = 4;
  static const int usernameMaxLength = 20;
  static const int passwordMinLength = 8;
  static const int passwordMaxLength = 64;

  static const int minWeightKg = 30;
  static const int maxWeightKg = 250;
  static const int minHeightCm = 100;
  static const int maxHeightCm = 230;
  static const int minAge = 10;
  static const int maxAge = 100;
  static const int minDailyGoal = 1000;
  static const int maxDailyGoal = 50000;
  static const int defaultDailyGoal = 10000;

  // ---------- Interfaz y rendimiento (RNF-03) ----------
  /// La UI se refresca como máximo 4 veces por segundo.
  static const Duration uiRefreshInterval = Duration(milliseconds: 250);

  /// Cada cuánto se agrega un punto a las gráficas en vivo.
  static const Duration chartSampleInterval = Duration(seconds: 1);

  /// Máximo de puntos visibles en las gráficas en vivo.
  static const int chartMaxPoints = 120;

  // ---------- Sensores ----------
  static const Duration sensorSamplingPeriod = Duration(milliseconds: 100);
  static const double gravity = 9.80665;

  /// Desviación de la aceleración respecto a la gravedad (m/s²).
  /// Por debajo: descanso. Entre ambos: caminata. Por encima: trote.
  /// Son valores de partida; se calibran probando en el celular.
  static const double motionRestMax = 0.6;
  static const double motionWalkMax = 3.5;

  /// Detector de pasos por acelerómetro (respaldo si no hay podómetro).
  static const double stepPeakThreshold = 1.3;
  static const int stepMinIntervalMs = 300;

  // ---------- GPS ----------
  /// Se descartan lecturas con precisión peor a estos metros.
  static const double gpsMaxAccuracyM = 30.0;

  /// Distancia mínima (m) para que el sistema entregue una nueva lectura.
  static const int gpsDistanceFilterM = 3;

  /// Movimientos menores a esto se consideran ruido del GPS.
  static const double gpsMinSegmentM = 2.0;

  /// Velocidad máxima creíble (m/s). Más que esto es un salto falso.
  static const double gpsMaxSpeedMs = 12.0;

  /// Si pasa este tiempo sin lecturas, la velocidad vuelve a 0.
  static const Duration gpsStaleAfter = Duration(seconds: 6);

  // ---------- Fitness ----------
  /// Zancada ≈ 41.5 % de la estatura.
  static const double strideFactor = 0.415;

  /// MET orientativos (kcal por kg por hora), del orden de los que publica
  /// el Compendio de Actividades Físicas.
  static const double metRest = 1.3;
  static const double metWalk = 3.5;
  static const double metJog = 7.0;
}