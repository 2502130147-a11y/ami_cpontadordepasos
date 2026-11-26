import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../history/data/training.dart';
import 'effort.dart';
import 'gps_tracker.dart';
import 'motion_hub.dart';

enum SessionPhase { ready, running, paused, finished }

/// Orquesta una sesión de entrenamiento con todos los sensores.
///
/// Batería (RNF-01):
///  - Los sensores solo existen mientras la sesión corre.
///  - [pause] y [dispose] cancelan TODOS los streams.
///  - En segundo plano ([toBackground]) se liberan acelerómetro y giroscopio
///    y la UI deja de repintarse. Solo siguen el GPS (servicio en primer
///    plano) y el podómetro, para no perder la ruta ni los pasos.
class TrackingStore extends ChangeNotifier {
  TrackingStore({required this.strideM, required this.weightKg});

  final double strideM;
  final double weightKg;

  final MotionHub motion = MotionHub();
  final GpsTracker gps = GpsTracker();

  SessionPhase phase = SessionPhase.ready;
  bool inBackground = false;
  bool locationGranted = false;
  bool activityGranted = false;
  DateTime? startedAt;

  final Stopwatch _clock = Stopwatch();
  Timer? _ticker;
  int _countedSec = 0;
  int _ticks = 0;
  int _runningTicks = 0;

  int restSec = 0, walkSec = 0, jogSec = 0;
  double kcal = 0;

  // Series para las gráficas (una muestra cada 2 s)
  final List<double> intensitySeries = [];
  final List<double> speedSeries = [];

  // Cadencia (para estimar el esfuerzo sin acelerómetro)
  final ListQueue<(DateTime, int)> _stepWindow = ListQueue();
  double cadence = 0; // pasos/min

  // ------------------------------------------------------------ lecturas
  int get elapsed => _clock.elapsed.inSeconds;
  int get steps => motion.steps;
  double get distanceM => gps.distanceM > 0 ? gps.distanceM : steps * strideM;
  bool get distanceFromGps => gps.distanceM > 0;

  double get avgKmh => elapsed == 0 ? 0 : (distanceM / 1000) / (elapsed / 3600);

  /// Ritmo en minutos por kilómetro.
  double get paceMinKm => distanceM < 30 ? 0 : (elapsed / 60) / (distanceM / 1000);

  Effort get effort {
    if (inBackground || !motion.motionActive || motion.accelFailed) return _effortFromCadence();
    return Effort.fromLevel(motion.effortLevel);
  }

  double get intensity =>
      (inBackground || !motion.motionActive || motion.accelFailed) ? effort.typicalLevel : motion.effortLevel;

  Effort _effortFromCadence() {
    final v = gps.speedKmh;
    if (cadence >= 140 || v >= 7.5) return Effort.jog;
    if (cadence >= 30 || v >= 1.5) return Effort.walk;
    return Effort.rest;
  }

  // ------------------------------------------------------------ control
  void begin({required bool location, required bool activity}) {
    if (phase != SessionPhase.ready) return;
    locationGranted = location;
    activityGranted = activity;
    startedAt = DateTime.now();
    phase = SessionPhase.running;
    _resumeAll();
    notifyListeners();
  }

  void pause() {
    if (phase != SessionPhase.running) return;
    _stopAll();
    phase = SessionPhase.paused;
    notifyListeners();
  }

  void resume() {
    if (phase != SessionPhase.paused) return;
    phase = SessionPhase.running;
    _resumeAll();
    notifyListeners();
  }

  void toBackground() {
    inBackground = true;
    motion.stopMotion(); // acelerómetro + giroscopio liberados
    _stepWindow
      ..clear()
      ..add((DateTime.now(), steps));
  }

  void toForeground() {
    if (!inBackground) return;
    inBackground = false;
    _stepWindow.clear();
    if (phase == SessionPhase.running) {
      // Continúa desde el valor estimado para que la gráfica no salte.
      motion.effortLevel = _effortFromCadence().typicalLevel;
      motion.startMotion();
    }
    notifyListeners();
  }

  /// Detiene todo y arma el registro para el historial.
  Training finish() {
    _stopAll();
    phase = SessionPhase.finished;
    final t = Training(
      startedAt: startedAt ?? DateTime.now(),
      durationSec: elapsed,
      steps: steps,
      distanceM: distanceM,
      kcal: kcal,
      avgKmh: avgKmh,
      maxKmh: gps.maxKmh,
      restSec: restSec,
      walkSec: walkSec,
      jogSec: jogSec,
      turns: motion.turns,
      maxTilt: motion.maxTilt,
      peakAngular: motion.peakAngular,
      route: List.of(gps.route),
      intensity: List.of(intensitySeries),
      speed: List.of(speedSeries),
    );
    notifyListeners();
    return t;
  }

  void _resumeAll() {
    _clock.start();
    if (!inBackground) motion.startMotion();
    motion.startSteps(permitted: activityGranted);
    if (locationGranted) gps.start();
    _runningTicks = 0;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), _tick);
  }

  void _stopAll() {
    _clock.stop();
    _ticker?.cancel();
    _ticker = null;
    motion.stopMotion();
    motion.stopSteps();
    gps.stop();
    _stepWindow.clear();
  }

  static double _r1(double v) => (v * 10).round() / 10;

  void _tick(Timer _) {
    gps.tick();
    _runningTicks++;
    // A los 3 s se marcan como "no disponibles" los sensores que no respondieron.
    if (_runningTicks == 12) motion.checkHealth();

    if (inBackground || !motion.motionActive) _updateCadence();

    final sec = elapsed;
    while (_countedSec < sec) {
      _countedSec++;
      final e = effort;
      switch (e) {
        case Effort.rest:
          restSec++;
        case Effort.walk:
          walkSec++;
        case Effort.jog:
          jogSec++;
      }
      kcal += e.met * weightKg / 3600; // MET x kg x horas
    }

    if (++_ticks % 8 == 0) {
      intensitySeries.add(_r1(intensity));
      speedSeries.add(_r1(gps.speedKmh));
    }

    if (!inBackground) notifyListeners(); // máximo 4 repintados por segundo
  }

  void _updateCadence() {
    final now = DateTime.now();
    _stepWindow.add((now, steps));
    while (_stepWindow.isNotEmpty && now.difference(_stepWindow.first.$1).inSeconds > 15) {
      _stepWindow.removeFirst();
    }
    cadence = 0;
    if (_stepWindow.isEmpty) return;
    final first = _stepWindow.first;
    final secs = now.difference(first.$1).inMilliseconds / 1000;
    if (secs >= 3) cadence = math.max(0, steps - first.$2) / secs * 60;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clock.stop();
    motion.dispose();
    gps.stop();
    super.dispose();
  }
}
