import 'dart:convert';

import 'route_point.dart';

/// Una muestra de las gráficas en vivo (una por segundo aprox.).
class ChartSample {
  const ChartSample({
    required this.second,
    required this.speedKmh,
    required this.intensityLevel,
  });

  /// Segundos transcurridos desde el inicio del entrenamiento.
  final int second;
  final double speedKmh;

  /// 0 = descanso, 1 = caminata, 2 = trote.
  final int intensityLevel;

  Map<String, dynamic> toMap() => {'s': second, 'v': speedKmh, 'i': intensityLevel};

  factory ChartSample.fromMap(Map<String, dynamic> m) => ChartSample(
    second: (m['s'] as num).toInt(),
    speedKmh: (m['v'] as num).toDouble(),
    intensityLevel: (m['i'] as num).toInt(),
  );
}

class WorkoutModel {
  const WorkoutModel({
    this.id,
    required this.userId,
    required this.startedAtMs,
    required this.endedAtMs,
    required this.durationSec,
    required this.steps,
    required this.distanceM,
    required this.calories,
    required this.avgSpeedMs,
    required this.maxSpeedMs,
    required this.restSec,
    required this.walkSec,
    required this.jogSec,
    required this.route,
    required this.samples,
  });

  final int? id;
  final int userId;
  final int startedAtMs;
  final int endedAtMs;
  final int durationSec;
  final int steps;
  final double distanceM;
  final double calories;
  final double avgSpeedMs;
  final double maxSpeedMs;

  /// Tiempo acumulado por intensidad (segundos).
  final int restSec;
  final int walkSec;
  final int jogSec;

  final List<RoutePoint> route;
  final List<ChartSample> samples;

  DateTime get startedAt => DateTime.fromMillisecondsSinceEpoch(startedAtMs);
  DateTime get endedAt => DateTime.fromMillisecondsSinceEpoch(endedAtMs);
  Duration get duration => Duration(seconds: durationSec);

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'user_id': userId,
    'started_at': startedAtMs,
    'ended_at': endedAtMs,
    'duration_sec': durationSec,
    'steps': steps,
    'distance_m': distanceM,
    'calories': calories,
    'avg_speed_ms': avgSpeedMs,
    'max_speed_ms': maxSpeedMs,
    'rest_sec': restSec,
    'walk_sec': walkSec,
    'jog_sec': jogSec,
    'route_json': jsonEncode(route.map((p) => p.toMap()).toList()),
    'samples_json': jsonEncode(samples.map((s) => s.toMap()).toList()),
  };

  factory WorkoutModel.fromMap(Map<String, Object?> m) {
    List<RoutePoint> route = const [];
    List<ChartSample> samples = const [];

    // Decodificación defensiva: un JSON dañado no debe tumbar la app.
    try {
      final r = m['route_json'] as String?;
      if (r != null && r.isNotEmpty) {
        route = (jsonDecode(r) as List)
            .map((e) => RoutePoint.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {
      route = const [];
    }
    try {
      final s = m['samples_json'] as String?;
      if (s != null && s.isNotEmpty) {
        samples = (jsonDecode(s) as List)
            .map((e) => ChartSample.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {
      samples = const [];
    }

    return WorkoutModel(
      id: m['id'] as int?,
      userId: (m['user_id'] as num).toInt(),
      startedAtMs: (m['started_at'] as num).toInt(),
      endedAtMs: (m['ended_at'] as num).toInt(),
      durationSec: (m['duration_sec'] as num).toInt(),
      steps: (m['steps'] as num).toInt(),
      distanceM: (m['distance_m'] as num).toDouble(),
      calories: (m['calories'] as num).toDouble(),
      avgSpeedMs: (m['avg_speed_ms'] as num).toDouble(),
      maxSpeedMs: (m['max_speed_ms'] as num).toDouble(),
      restSec: (m['rest_sec'] as num).toInt(),
      walkSec: (m['walk_sec'] as num).toInt(),
      jogSec: (m['jog_sec'] as num).toInt(),
      route: route,
      samples: samples,
    );
  }
}