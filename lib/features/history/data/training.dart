import 'dart:convert';

import 'package:latlong2/latlong.dart';

/// Un entrenamiento guardado en el historial.
class Training {
  const Training({
    this.id,
    required this.startedAt,
    required this.durationSec,
    required this.steps,
    required this.distanceM,
    required this.kcal,
    required this.avgKmh,
    required this.maxKmh,
    required this.restSec,
    required this.walkSec,
    required this.jogSec,
    required this.turns,
    required this.maxTilt,
    required this.peakAngular,
    required this.route,
    required this.intensity,
    required this.speed,
  });

  final int? id;
  final DateTime startedAt;
  final int durationSec;
  final int steps;
  final double distanceM;
  final double kcal;
  final double avgKmh;
  final double maxKmh;
  final int restSec;
  final int walkSec;
  final int jogSec;
  final int turns; // giros detectados por el giroscopio
  final double maxTilt; // inclinación máxima (°)
  final double peakAngular; // velocidad angular pico (°/s)
  final List<LatLng> route;
  final List<double> intensity; // muestras cada 2 s (m/s²)
  final List<double> speed; // muestras cada 2 s (km/h)

  double get km => distanceM / 1000;
  int get activeSec => walkSec + jogSec;
  DateTime get endedAt => startedAt.add(Duration(seconds: durationSec));

  Training withId(int newId) => Training(
        id: newId,
        startedAt: startedAt,
        durationSec: durationSec,
        steps: steps,
        distanceM: distanceM,
        kcal: kcal,
        avgKmh: avgKmh,
        maxKmh: maxKmh,
        restSec: restSec,
        walkSec: walkSec,
        jogSec: jogSec,
        turns: turns,
        maxTilt: maxTilt,
        peakAngular: peakAngular,
        route: route,
        intensity: intensity,
        speed: speed,
      );

  static double _r6(double v) => (v * 1e6).round() / 1e6;

  Map<String, Object?> toRow() => {
        if (id != null) 'id': id,
        'started_at': startedAt.millisecondsSinceEpoch,
        'duration_sec': durationSec,
        'steps': steps,
        'distance_m': distanceM,
        'kcal': kcal,
        'avg_kmh': avgKmh,
        'max_kmh': maxKmh,
        'rest_sec': restSec,
        'walk_sec': walkSec,
        'jog_sec': jogSec,
        'turns': turns,
        'max_tilt': maxTilt,
        'peak_angular': peakAngular,
        'route': jsonEncode(route.map((p) => [_r6(p.latitude), _r6(p.longitude)]).toList()),
        'series': jsonEncode({'i': intensity, 's': speed}),
      };

  factory Training.fromRow(Map<String, Object?> r) {
    double d(String k) => (r[k] as num? ?? 0).toDouble();
    int i(String k) => (r[k] as num? ?? 0).toInt();

    var route = <LatLng>[];
    var intensity = <double>[];
    var speed = <double>[];
    try {
      route = (jsonDecode(r['route'] as String? ?? '[]') as List).map((e) {
        final l = e as List;
        return LatLng((l[0] as num).toDouble(), (l[1] as num).toDouble());
      }).toList();
      final s = jsonDecode(r['series'] as String? ?? '{}') as Map<String, dynamic>;
      intensity = ((s['i'] as List?) ?? const []).map((e) => (e as num).toDouble()).toList();
      speed = ((s['s'] as List?) ?? const []).map((e) => (e as num).toDouble()).toList();
    } catch (_) {
      // Datos dañados: se muestra el entrenamiento sin ruta ni gráficas.
    }

    return Training(
      id: i('id'),
      startedAt: DateTime.fromMillisecondsSinceEpoch(i('started_at')),
      durationSec: i('duration_sec'),
      steps: i('steps'),
      distanceM: d('distance_m'),
      kcal: d('kcal'),
      avgKmh: d('avg_kmh'),
      maxKmh: d('max_kmh'),
      restSec: i('rest_sec'),
      walkSec: i('walk_sec'),
      jogSec: i('jog_sec'),
      turns: i('turns'),
      maxTilt: d('max_tilt'),
      peakAngular: d('peak_angular'),
      route: route,
      intensity: intensity,
      speed: speed,
    );
  }
}
