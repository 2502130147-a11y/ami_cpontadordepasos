import 'dart:math' as math;

import '../constants/app_constants.dart';

/// Matemáticas de GPS y orientación. Todo es función pura.
class GeoUtils {
  GeoUtils._();

  static const double earthRadiusM = 6371000.0;

  static double _rad(double deg) => deg * math.pi / 180.0;
  static double degrees(double rad) => rad * 180.0 / math.pi;

  /// Distancia en metros entre dos coordenadas (fórmula de Haversine).
  static double distanceMeters(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * earthRadiusM * math.asin(math.min(1.0, math.sqrt(a.toDouble())));
  }

  /// Longitud total de una ruta [(lat, lon), ...].
  static double pathLengthMeters(List<(double, double)> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += distanceMeters(
        points[i - 1].$1,
        points[i - 1].$2,
        points[i].$1,
        points[i].$2,
      );
    }
    return total;
  }

  /// ¿La lectura es lo bastante precisa para usarla?
  static bool isAccurate(double accuracyMeters) =>
      accuracyMeters > 0 && accuracyMeters <= AppConstants.gpsMaxAccuracyM;

  /// Rechaza saltos imposibles (por ejemplo, 500 m en 2 s).
  static bool isPlausibleMove({
    required double meters,
    required Duration elapsed,
  }) {
    final seconds = elapsed.inMilliseconds / 1000.0;
    if (seconds <= 0) return false;
    return meters / seconds <= AppConstants.gpsMaxSpeedMs;
  }

  static double speedMs(double meters, Duration elapsed) {
    final seconds = elapsed.inMilliseconds / 1000.0;
    return seconds <= 0 ? 0 : meters / seconds;
  }

  // ---------- Acelerómetro ----------

  static double accelMagnitude(double x, double y, double z) =>
      math.sqrt(x * x + y * y + z * z);

  /// Cuánto se aleja la aceleración de la gravedad (m/s²).
  /// En reposo es ~0; al caminar o trotar sube.
  static double motionDeviation(double x, double y, double z) =>
      (accelMagnitude(x, y, z) - AppConstants.gravity).abs();

  /// Inclinación adelante/atrás en grados.
  /// 0° = celular acostado, 90° = vertical.
  static double pitchDegrees(double x, double y, double z) =>
      degrees(math.atan2(y, math.sqrt(x * x + z * z)));

  /// Inclinación lateral en grados (izquierda/derecha).
  static double rollDegrees(double x, double y, double z) =>
      degrees(math.atan2(x, math.sqrt(y * y + z * z)));

  // ---------- Giroscopio ----------

  /// Velocidad angular total en grados/segundo (la entrada viene en rad/s).
  static double angularSpeedDegPerSec(double gx, double gy, double gz) =>
      degrees(math.sqrt(gx * gx + gy * gy + gz * gz));
}