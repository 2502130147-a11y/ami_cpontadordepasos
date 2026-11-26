import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../core/constants/app_constants.dart';

/// Lectura de GPS independiente del plugin.
class GpsFix {
  const GpsFix({
    required this.lat,
    required this.lon,
    required this.accuracyM,
    required this.speedMs,
    required this.timestamp,
  });

  factory GpsFix.fromPosition(Position p) => GpsFix(
    lat: p.latitude,
    lon: p.longitude,
    accuracyM: p.accuracy,
    speedMs: (p.speed.isNaN || p.speed < 0) ? 0 : p.speed,
    timestamp: DateTime.now(),
  );

  final double lat;
  final double lon;
  final double accuracyM;

  /// Velocidad en m/s reportada por el GPS (nunca negativa).
  final double speedMs;
  final DateTime timestamp;
}

/// Envoltorio de `geolocator`.
///
/// Segundo plano: el stream se crea CON `foregroundNotificationConfig`.
/// Eso levanta un servicio en primer plano de ubicación con notificación
/// fija mientras dura el entrenamiento. Se inicia con la app visible
/// (Android 12+ no permite iniciar uno desde segundo plano).
class LocationService {
  StreamSubscription<Position>? _posSub;
  StreamSubscription<ServiceStatus>? _statusSub;

  bool get isTracking => _posSub != null;

  Future<bool> isServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  Future<void> openLocationSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (_) {}
  }

  /// Última posición conocida: inmediata, sirve para centrar el mapa ya.
  Future<GpsFix?> lastKnown() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      return p == null ? null : GpsFix.fromPosition(p);
    } catch (_) {
      return null;
    }
  }

  /// Posición actual con tiempo límite. Devuelve null si no llega a tiempo.
  Future<GpsFix?> currentFix({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
      return GpsFix.fromPosition(p);
    } catch (_) {
      return null;
    }
  }

  /// Inicia el seguimiento continuo (con servicio en primer plano).
  void startTracking({
    required void Function(GpsFix fix) onFix,
    required void Function(Object error) onError,
    required void Function(bool enabled) onServiceStatus,
  }) {
    if (_posSub != null) return;

    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: AppConstants.gpsDistanceFilterM,
      intervalDuration: const Duration(seconds: 1),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'FitPulse · entrenamiento en curso',
        notificationText: 'Registrando tu ruta y tus pasos',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );

    try {
      _posSub = Geolocator.getPositionStream(locationSettings: settings).listen(
            (p) => onFix(GpsFix.fromPosition(p)),
        onError: (Object e) => onError(e),
        cancelOnError: false,
      );
      _statusSub = Geolocator.getServiceStatusStream().listen(
            (s) => onServiceStatus(s == ServiceStatus.enabled),
        onError: (Object _) {},
      );
    } catch (e) {
      onError(e);
    }
  }

  /// Cancela GPS y servicio en primer plano (RNF-01).
  Future<void> stopTracking() async {
    final pos = _posSub;
    final status = _statusSub;
    _posSub = null;
    _statusSub = null;
    await pos?.cancel();
    await status?.cancel();
  }
}