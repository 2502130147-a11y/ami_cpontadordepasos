import 'dart:async';
import 'dart:math' as math;

import 'package:pedometer/pedometer.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Acelerómetro + giroscopio + podómetro.
///
/// Cada grupo se enciende y se apaga por separado para ahorrar batería:
///  - [startMotion]/[stopMotion]: acelerómetro y giroscopio.
///  - [startSteps]/[stopSteps]: podómetro (STEP_COUNTER).
/// Si el teléfono no tiene podómetro (o no hay permiso) los pasos se
/// detectan con picos del acelerómetro.
class MotionHub {
  static const double g = 9.80665;

  // ---- Acelerómetro (m/s²)
  double ax = 0, ay = 0, az = 0;
  double magnitude = g;

  /// Aceleración dinámica suavizada |a| - g: mide la intensidad.
  double effortLevel = 0;
  double pitch = 0; // inclinación adelante/atrás (°)
  double roll = 0; // inclinación lateral (°)
  double maxTilt = 0;

  // ---- Giroscopio (rad/s)
  double gx = 0, gy = 0, gz = 0;
  double angularDeg = 0; // velocidad angular total suavizada (°/s)
  double peakAngular = 0;
  double heading = 0; // orientación integrada en el eje Z (°)
  int turns = 0; // giros bruscos detectados
  DateTime _lastTurn = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _lastGyroAt;

  // ---- Disponibilidad
  bool accelSeen = false;
  bool gyroSeen = false;
  bool pedometerSeen = false;
  bool accelFailed = false;
  bool gyroFailed = false;
  bool pedometerFailed = false;

  // ---- Pasos
  int _pedBanked = 0;
  int? _pedBase;
  int _pedLast = 0;
  int _accSteps = 0;
  double _lowPass = g;
  bool _peak = false;
  DateTime _lastStepAt = DateTime.fromMillisecondsSinceEpoch(0);

  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<StepCount>? _pedSub;

  bool get motionActive => _accSub != null || _gyroSub != null;
  bool get stepsActive => _pedSub != null;

  /// true si los pasos vienen del podómetro del sistema.
  bool get usingPedometer => pedometerSeen && !pedometerFailed;

  int get steps {
    if (usingPedometer) {
      final seg = _pedBase == null ? 0 : math.max(0, _pedLast - _pedBase!);
      return _pedBanked + seg;
    }
    return _accSteps;
  }

  // ------------------------------------------------------------ control
  void startMotion() {
    if (_accSub == null && !accelFailed) {
      _accSub = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen(
        _onAcc,
        onError: (Object _) {
          accelFailed = true;
          _accSub?.cancel();
          _accSub = null;
        },
        cancelOnError: true,
      );
    }
    if (_gyroSub == null && !gyroFailed) {
      _lastGyroAt = null;
      _gyroSub = gyroscopeEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
        _onGyro,
        onError: (Object _) {
          gyroFailed = true;
          _gyroSub?.cancel();
          _gyroSub = null;
        },
        cancelOnError: true,
      );
    }
  }

  void stopMotion() {
    _accSub?.cancel();
    _gyroSub?.cancel();
    _accSub = null;
    _gyroSub = null;
  }

  void startSteps({required bool permitted}) {
    if (_pedSub != null) return;
    if (!permitted) {
      pedometerFailed = true; // se usará el acelerómetro
      return;
    }
    try {
      _pedSub = Pedometer.stepCountStream.listen(
        _onStep,
        onError: (Object _) {
          pedometerFailed = true;
          _pedSub?.cancel();
          _pedSub = null;
        },
        cancelOnError: true,
      );
    } catch (_) {
      pedometerFailed = true;
    }
  }

  void stopSteps() {
    if (_pedBase != null) _pedBanked += math.max(0, _pedLast - _pedBase!);
    _pedBase = null;
    _pedSub?.cancel();
    _pedSub = null;
  }

  void dispose() {
    stopMotion();
    stopSteps();
  }

  /// Marca como no disponibles los sensores que nunca enviaron datos.
  void checkHealth() {
    if (_accSub != null && !accelSeen) accelFailed = true;
    if (_gyroSub != null && !gyroSeen) gyroFailed = true;
  }

  // ------------------------------------------------------------ eventos
  void _onAcc(AccelerometerEvent e) {
    accelSeen = true;
    ax = e.x;
    ay = e.y;
    az = e.z;
    magnitude = math.sqrt(ax * ax + ay * ay + az * az);

    // Intensidad: media móvil exponencial de |a| - g.
    effortLevel = 0.9 * effortLevel + 0.1 * (magnitude - g).abs();

    // Orientación a partir de la gravedad.
    final p = math.atan2(-ax, math.sqrt(ay * ay + az * az)) * 180 / math.pi;
    final r = math.atan2(ay, az) * 180 / math.pi;
    pitch = 0.85 * pitch + 0.15 * p;
    roll = 0.85 * roll + 0.15 * r;
    final tilt = math.max(pitch.abs(), (90 - roll.abs()).abs());
    if (tilt > maxTilt && tilt <= 90) maxTilt = tilt;

    // Detector de pasos por picos (respaldo sin podómetro).
    _lowPass = 0.75 * _lowPass + 0.25 * magnitude;
    final now = DateTime.now();
    if (!_peak && _lowPass > g + 1.2 && now.difference(_lastStepAt).inMilliseconds > 280) {
      _peak = true;
      _lastStepAt = now;
      _accSteps++;
    } else if (_peak && _lowPass < g + 0.3) {
      _peak = false;
    }
  }

  void _onGyro(GyroscopeEvent e) {
    gyroSeen = true;
    gx = e.x;
    gy = e.y;
    gz = e.z;
    final now = DateTime.now();
    final prev = _lastGyroAt;
    _lastGyroAt = now;
    if (prev != null) {
      final dt = now.difference(prev).inMicroseconds / 1e6;
      if (dt > 0 && dt < 0.5) heading = (heading + gz * dt * 180 / math.pi) % 360;
    }
    final w = math.sqrt(gx * gx + gy * gy + gz * gz) * 180 / math.pi;
    angularDeg = 0.7 * angularDeg + 0.3 * w;
    if (w > peakAngular) peakAngular = w;
    if (w > 120 && now.difference(_lastTurn).inMilliseconds > 900) {
      turns++;
      _lastTurn = now;
    }
  }

  void _onStep(StepCount e) {
    if (!pedometerSeen) {
      // El podómetro tomó el control: se conservan los pasos ya contados.
      pedometerSeen = true;
      _pedBanked = _accSteps;
    }
    _pedLast = e.steps;
    _pedBase ??= e.steps;
  }
}
