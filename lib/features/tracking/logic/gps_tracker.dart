import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// GPS: coordenadas en tiempo real, trazado de la ruta, distancia y velocidad.
class GpsTracker {
  final List<LatLng> route = [];
  LatLng? current;
  double distanceM = 0;
  double speedKmh = 0;
  double maxKmh = 0;
  double accuracyM = 0;
  bool serviceOn = true;
  bool hasFix = false;

  StreamSubscription<Position>? _sub;
  bool _wanted = false;
  bool _starting = false;
  DateTime _lastFixAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get active => _sub != null;

  Future<void> start() async {
    _wanted = true;
    if (_sub != null || _starting) return;
    _starting = true;
    try {
      serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn || !_wanted) return;

      // Última posición conocida: centra el mapa de inmediato.
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) current ??= LatLng(last.latitude, last.longitude);
      } catch (_) {}
      if (!_wanted) return;

      _sub = Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
          intervalDuration: const Duration(seconds: 2),
          // Servicio en primer plano: la ruta se sigue registrando con la
          // pantalla apagada o con la app en segundo plano.
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Amatista',
            notificationText: 'Registrando tu entrenamiento…',
            notificationChannelName: 'Entrenamiento en curso',
            enableWakeLock: true,
            setOngoing: true,
          ),
        ),
      ).listen(_onPosition, onError: (Object _) => hasFix = false);
    } catch (_) {
      hasFix = false;
    } finally {
      _starting = false;
      if (!_wanted) stop();
    }
  }

  void stop() {
    _wanted = false;
    _sub?.cancel();
    _sub = null;
    hasFix = false;
    speedKmh = 0;
  }

  /// Se llama periódicamente: si no hay lecturas recientes, la velocidad es 0.
  void tick() {
    if (DateTime.now().difference(_lastFixAt).inSeconds > 7) {
      speedKmh = 0;
      if (active) hasFix = false;
    }
  }

  void _onPosition(Position p) {
    _lastFixAt = DateTime.now();
    accuracyM = p.accuracy;
    final point = LatLng(p.latitude, p.longitude);
    current = point;
    hasFix = p.accuracy <= 35;
    if (!hasFix) return; // lecturas muy imprecisas no entran a la ruta

    if (route.isNotEmpty) {
      final d = Geolocator.distanceBetween(
        route.last.latitude,
        route.last.longitude,
        point.latitude,
        point.longitude,
      );
      if (d < 2.5) return; // ruido estando quieto
      distanceM += d;
    }
    route.add(point);
    speedKmh = math.max(0.0, p.speed) * 3.6;
    if (speedKmh > maxKmh && speedKmh < 45) maxKmh = speedKmh;
  }
}
