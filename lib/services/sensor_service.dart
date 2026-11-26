import 'dart:async';
import 'dart:collection';

import 'package:pedometer/pedometer.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/geo_utils.dart';
import '../data/models/intensity.dart';

/// Foto de los sensores en un instante (la UI la lee 4 veces por segundo).
class SensorSnapshot {
  const SensorSnapshot({
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    required this.pitch,
    required this.roll,
    required this.angularSpeed,
    required this.deviation,
    required this.intensity,
  });

  static const SensorSnapshot zero = SensorSnapshot(
    ax: 0,
    ay: 0,
    az: 0,
    gx: 0,
    gy: 0,
    gz: 0,
    pitch: 0,
    roll: 0,
    angularSpeed: 0,
    deviation: 0,
    intensity: Intensity.rest,
  );

  /// Acelerómetro (m/s²).
  final double ax;
  final double ay;
  final double az;

  /// Giroscopio (rad/s).
  final double gx;
  final double gy;
  final double gz;

  /// Inclinación adelante/atrás y lateral, en grados.
  final double pitch;
  final double roll;

  /// Velocidad angular total (grados/s).
  final double angularSpeed;

  /// Desviación suavizada respecto a la gravedad (m/s²).
  final double deviation;
  final Intensity intensity;
}

/// Acelerómetro, giroscopio y podómetro.
///
/// - Pasivo: guarda el último valor y la UI lo lee con un temporizador.
/// - Cada sensor se puede liberar por separado (RNF-01).
/// - Fallbacks (RNF-04): si no hay podómetro o no hay permiso, los pasos
///   se estiman con el acelerómetro. Si falta un sensor, se marca como no
///   disponible y la app sigue funcionando.
class SensorService {
  static const int _windowSize = 15;
  static const Duration _healthTimeout = Duration(seconds: 3);
  static const int _fallbackAfterAccelSteps = 25;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<StepCount>? _stepSub;

  // Últimos valores
  double _ax = 0, _ay = 0, _az = 0;
  double _gx = 0, _gy = 0, _gz = 0;

  // Suavizado de la intensidad (ventana de ~1.5 s)
  final ListQueue<double> _window = ListQueue<double>();
  double _windowSum = 0;

  // Salud de los sensores
  bool _accelFailed = false;
  bool _gyroFailed = false;
  bool _pedometerFailed = false;
  int _accelEvents = 0;
  int _gyroEvents = 0;
  DateTime? _accelStartedAt;
  DateTime? _gyroStartedAt;

  // Pasos
  bool _paused = false;
  int _pedoSteps = 0;
  int _pedoEvents = 0;
  int _lastRaw = -1;
  int _accelSteps = 0;
  bool _fellBack = false;

  // Detector de pasos por acelerómetro
  double _filtered = 0;
  bool _aboveThreshold = false;
  int _lastStepMs = 0;

  // ---------- Lectura ----------

  SensorSnapshot get snapshot {
    final dev = _window.isEmpty ? 0.0 : _windowSum / _window.length;
    return SensorSnapshot(
      ax: _ax,
      ay: _ay,
      az: _az,
      gx: _gx,
      gy: _gy,
      gz: _gz,
      pitch: GeoUtils.pitchDegrees(_ax, _ay, _az),
      roll: GeoUtils.rollDegrees(_ax, _ay, _az),
      angularSpeed: GeoUtils.angularSpeedDegPerSec(_gx, _gy, _gz),
      deviation: dev,
      intensity: Intensity.fromMotion(dev),
    );
  }

  bool get accelerometerAvailable => !_accelFailed;
  bool get gyroscopeAvailable => !_gyroFailed;

  /// ¿Se están contando pasos por acelerómetro en vez de por podómetro?
  bool get usingAccelSteps => _pedometerFailed || _fellBack;

  int get steps => usingAccelSteps ? _accelSteps : _pedoSteps;

  bool get motionSensorsActive => _accelSub != null || _gyroSub != null;

  // ---------- Ciclo de vida ----------

  /// Pone todo en cero para un entrenamiento nuevo.
  void resetSession() {
    _pedoSteps = 0;
    _pedoEvents = 0;
    _lastRaw = -1;
    _accelSteps = 0;
    _fellBack = false;
    _pedometerFailed = false;
    _paused = false;
    _clearMotionState();
  }

  /// Durante la pausa no se cuentan pasos.
  void setPaused(bool paused) => _paused = paused;

  void startMotionSensors() {
    if (_accelSub == null) {
      _accelFailed = false;
      _accelEvents = 0;
      _accelStartedAt = DateTime.now();
      try {
        _accelSub = accelerometerEventStream(
          samplingPeriod: AppConstants.sensorSamplingPeriod,
        ).listen(
          _onAccel,
          onError: (Object _) => _accelFailed = true,
          cancelOnError: false,
        );
      } catch (_) {
        _accelFailed = true;
      }
    }
    if (_gyroSub == null) {
      _gyroFailed = false;
      _gyroEvents = 0;
      _gyroStartedAt = DateTime.now();
      try {
        _gyroSub = gyroscopeEventStream(
          samplingPeriod: AppConstants.sensorSamplingPeriod,
        ).listen(
          _onGyro,
          onError: (Object _) => _gyroFailed = true,
          cancelOnError: false,
        );
      } catch (_) {
        _gyroFailed = true;
      }
    }
  }

  /// Libera acelerómetro y giroscopio (segundo plano, pausa, salida).
  Future<void> stopMotionSensors() async {
    final a = _accelSub;
    final g = _gyroSub;
    _accelSub = null;
    _gyroSub = null;
    await a?.cancel();
    await g?.cancel();
    _clearMotionState();
  }

  void startPedometer({required bool permissionGranted}) {
    if (!permissionGranted) {
      _pedometerFailed = true; // sin permiso: pasos por acelerómetro
      return;
    }
    if (_stepSub != null) return;
    _pedometerFailed = false;
    _lastRaw = -1; // el primer evento será la línea base
    try {
      _stepSub = Pedometer.stepCountStream.listen(
        _onStep,
        onError: (Object _) => _pedometerFailed = true,
        cancelOnError: false,
      );
    } catch (_) {
      _pedometerFailed = true;
    }
  }

  Future<void> stopPedometer() async {
    final s = _stepSub;
    _stepSub = null;
    await s?.cancel();
  }

  Future<void> dispose() async {
    await stopMotionSensors();
    await stopPedometer();
  }

  /// Si un sensor lleva 3 s activo sin mandar nada, se marca no disponible.
  /// Se llama desde el temporizador de la UI.
  void checkHealth() {
    final now = DateTime.now();
    final a = _accelStartedAt;
    if (_accelSub != null &&
        _accelEvents == 0 &&
        a != null &&
        now.difference(a) > _healthTimeout) {
      _accelFailed = true;
    }
    final g = _gyroStartedAt;
    if (_gyroSub != null &&
        _gyroEvents == 0 &&
        g != null &&
        now.difference(g) > _healthTimeout) {
      _gyroFailed = true;
    }
  }

  // ---------- Procesamiento ----------

  void _clearMotionState() {
    _window.clear();
    _windowSum = 0;
    _filtered = 0;
    _aboveThreshold = false;
    _ax = 0;
    _ay = 0;
    _az = 0;
    _gx = 0;
    _gy = 0;
    _gz = 0;
  }

  void _onAccel(AccelerometerEvent e) {
    _accelEvents++;
    _accelFailed = false;
    _ax = e.x;
    _ay = e.y;
    _az = e.z;

    final magnitude = GeoUtils.accelMagnitude(e.x, e.y, e.z);
    final signed = magnitude - AppConstants.gravity;

    _window.addLast(signed.abs());
    _windowSum += signed.abs();
    if (_window.length > _windowSize) {
      _windowSum -= _window.removeFirst();
    }

    _detectStep(signed);
  }

  void _onGyro(GyroscopeEvent e) {
    _gyroEvents++;
    _gyroFailed = false;
    _gx = e.x;
    _gy = e.y;
    _gz = e.z;
  }

  /// Detector de pasos por picos con histéresis (respaldo del podómetro).
  void _detectStep(double signedDeviation) {
    _filtered = _filtered * 0.6 + signedDeviation * 0.4;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (!_aboveThreshold) {
      if (_filtered > AppConstants.stepPeakThreshold &&
          now - _lastStepMs >= AppConstants.stepMinIntervalMs) {
        _aboveThreshold = true;
        _lastStepMs = now;
        if (!_paused) {
          _accelSteps++;
          // El podómetro nunca respondió y ya hay pasos claros: se usa el respaldo.
          if (_pedoEvents == 0 && _accelSteps >= _fallbackAfterAccelSteps) {
            _fellBack = true;
          }
        }
      }
    } else if (_filtered < AppConstants.stepPeakThreshold * 0.5) {
      _aboveThreshold = false;
    }
  }

  void _onStep(StepCount e) {
    _pedoEvents++;
    final raw = e.steps;
    if (_lastRaw < 0) {
      _lastRaw = raw; // línea base: el contador del sistema acumula desde el arranque
      return;
    }
    var delta = raw - _lastRaw;
    if (delta < 0) delta = raw; // el teléfono se reinició
    _lastRaw = raw;
    if (!_paused) _pedoSteps += delta;
  }
}