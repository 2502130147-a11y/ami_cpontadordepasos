import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/fitness_calculator.dart';
import '../core/utils/formatters.dart';
import '../core/utils/geo_utils.dart';
import '../data/models/intensity.dart';
import '../data/models/route_point.dart';
import '../data/models/user_model.dart';
import '../data/models/workout_model.dart';
import '../data/repositories/workout_repository.dart';
import '../services/background_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/permission_service.dart';
import '../services/sensor_service.dart';

enum WorkoutStatus {
  idle,
  running,
  paused,
  saving,
  saved,
  saveFailed,
  discarded,
}

enum GpsStatus { off, searching, active }

/// Por qué el GPS no está funcionando (la UI ofrece la acción adecuada).
enum GpsProblem { none, permission, serviceOff, error }

/// Cerebro del entrenamiento en vivo.
///
/// Se crea al ENTRAR a la pantalla de entrenamiento y se destruye al salir:
/// `dispose()` cancela GPS, sensores, temporizador y observador (RNF-01).
///
/// Reglas de ahorro de batería:
/// - Segundo plano con GPS: se liberan acelerómetro y giroscopio, el GPS
///   sigue con su servicio en primer plano y el temporizador baja a 1 s.
/// - Segundo plano sin GPS: se pausa todo y se reanuda al volver.
/// - Pausa manual: se liberan acelerómetro, giroscopio y GPS.
class WorkoutProvider extends ChangeNotifier {
  WorkoutProvider({
    required UserModel user,
    LocationService? location,
    SensorService? sensors,
    PermissionService? permissions,
    BackgroundService? background,
    NotificationService? notifications,
    WorkoutRepository? repository,
  })  : _user = user,
        _location = location ?? LocationService(),
        _sensors = sensors ?? SensorService(),
        _permissions = permissions ?? PermissionService(),
        _background = background ?? BackgroundService(),
        _notifications = notifications ?? NotificationService(),
        _repository = repository ?? WorkoutRepository();

  // Valores de respaldo si la cuenta no tiene datos corporales.
  static const double defaultWeightKg = 70;
  static const double defaultHeightCm = 170;

  static const int _minSaveSeconds = 5;
  static const int _maxSavedSamples = 600;
  static const Duration _notifyGap = Duration(milliseconds: 200);
  static const Duration _backgroundTick = Duration(seconds: 1);

  // Umbrales de velocidad (m/s) para clasificar la intensidad cuando el
  // acelerómetro no está disponible (por ejemplo, en segundo plano).
  static const double _speedRestMax = 0.6;
  static const double _speedWalkMax = 2.0;

  final UserModel _user;
  final LocationService _location;
  final SensorService _sensors;
  final PermissionService _permissions;
  final BackgroundService _background;
  final NotificationService _notifications;
  final WorkoutRepository _repository;

  final Stopwatch _sw = Stopwatch();
  Timer? _ticker;

  WorkoutStatus _status = WorkoutStatus.idle;
  bool _disposed = false;
  bool _autoPaused = false;
  bool _locationGranted = false;
  DateTime? _startedAt;
  DateTime? _endedAt;
  Duration _lastElapsed = Duration.zero;
  int _lastSampleSec = -1;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
  int? _finalSteps;
  String? _notice;

  // GPS
  GpsProblem _gpsProblem = GpsProblem.none;
  bool _hasFix = false;
  DateTime? _lastFixAt;
  double? _curLat;
  double? _curLon;
  RoutePoint? _lastPoint;
  final List<RoutePoint> _route = [];
  int _routeVersion = 0;
  double _gpsDistanceM = 0;
  double _speedMs = 0;
  double _maxSpeedMs = 0;

  // Métricas
  double _calories = 0;
  int _restMs = 0;
  int _walkMs = 0;
  int _jogMs = 0;
  Intensity _intensity = Intensity.rest;
  final List<ChartSample> _samples = [];
  List<ChartSample> _recent = const [];

  // ---------- Estado público ----------

  WorkoutStatus get status => _status;
  bool get isActive =>
      _status == WorkoutStatus.running || _status == WorkoutStatus.paused;
  bool get isRunning => _status == WorkoutStatus.running;
  bool get isPaused => _status == WorkoutStatus.paused;

  /// Se pausó sola porque la app pasó a segundo plano sin GPS.
  bool get autoPaused => _autoPaused;
  bool get inBackground => _background.isInBackground;

  /// Aviso para mostrar en la UI (se limpia con [clearNotice]).
  String? get notice => _notice;
  void clearNotice() => _notice = null;

  Duration get elapsed => _sw.elapsed;
  int get steps => _finalSteps ?? _sensors.steps;

  /// Los pasos se estiman con el acelerómetro (no hay podómetro o permiso).
  bool get stepsEstimated => _sensors.usingAccelSteps;

  /// Distancia por GPS; si el GPS no aportó nada, estimación por pasos.
  double get distanceM {
    if (_gpsDistanceM > 0) return _gpsDistanceM;
    return FitnessCalculator.stepsToMeters(steps, _heightCm);
  }

  bool get distanceFromSteps => _gpsDistanceM <= 0 && steps > 0;

  double get speedMs => _speedMs;
  double get speedKmh => _speedMs * 3.6;
  double get maxSpeedMs => _maxSpeedMs;
  double get avgSpeedMs =>
      FitnessCalculator.averageSpeedMs(distanceM, _sw.elapsed);
  double get calories => _calories;

  Intensity get intensity => _intensity;
  Duration get restTime => Duration(milliseconds: _restMs);
  Duration get walkTime => Duration(milliseconds: _walkMs);
  Duration get jogTime => Duration(milliseconds: _jogMs);

  /// Lectura actual de acelerómetro, giroscopio e inclinación.
  SensorSnapshot get sensor => _sensors.snapshot;
  bool get accelerometerAvailable => _sensors.accelerometerAvailable;
  bool get gyroscopeAvailable => _sensors.gyroscopeAvailable;

  List<ChartSample> get recentSamples => _recent;

  // GPS y mapa
  List<RoutePoint> get route => UnmodifiableListView(_route);
  int get routeVersion => _routeVersion;
  RoutePoint? get startPoint => _route.isEmpty ? null : _route.first;
  int get gpsPoints => _route.length;
  GpsProblem get gpsProblem => _gpsProblem;

  ({double lat, double lon})? get currentPosition {
    final lat = _curLat;
    final lon = _curLon;
    if (lat == null || lon == null) return null;
    return (lat: lat, lon: lon);
  }

  GpsStatus get gpsStatus {
    if (_gpsProblem != GpsProblem.none) return GpsStatus.off;
    if (!_hasFix) return GpsStatus.searching;
    return GpsStatus.active;
  }

  String get gpsLabel {
    switch (gpsStatus) {
      case GpsStatus.off:
        return 'GPS apagado';
      case GpsStatus.searching:
        return 'Buscando…';
      case GpsStatus.active:
        return 'GPS · ${_route.length} pts';
    }
  }

  bool get usingDefaultBodyData => !_user.hasBodyData;

  double get _weightKg {
    final w = _user.weightKg;
    return (w != null && w > 0) ? w : defaultWeightKg;
  }

  double get _heightCm {
    final h = _user.heightCm;
    return (h != null && h > 0) ? h : defaultHeightCm;
  }

  // ---------- Inicio ----------

  /// Inicia el entrenamiento. Los permisos los pide la pantalla ANTES
  /// (con su diálogo informativo) y aquí solo llegan los resultados.
  Future<void> start({
    required bool locationGranted,
    required bool activityGranted,
  }) async {
    if (_status != WorkoutStatus.idle) return;

    _locationGranted = locationGranted;
    _status = WorkoutStatus.running;
    _startedAt = DateTime.now();
    _sensors.resetSession();
    _sw
      ..reset()
      ..start();
    _lastElapsed = Duration.zero;

    _sensors.startMotionSensors();
    _sensors.startPedometer(permissionGranted: activityGranted);
    _background.attach(
      onBackground: _onBackground,
      onForeground: _onForeground,
    );
    _startTicker();
    _notify(force: true);

    unawaited(_notifications.init());
    await _startGps();
  }

  // ---------- Pausa y reanudación ----------

  Future<void> pause() async {
    if (_status != WorkoutStatus.running) return;
    _autoPaused = false;
    await _doPause();
  }

  Future<void> resume() async {
    if (_status != WorkoutStatus.paused || _background.isInBackground) return;
    await _doResume();
  }

  Future<void> _doPause() async {
    if (_status != WorkoutStatus.running) return;
    _accumulate();
    _sw.stop();
    _status = WorkoutStatus.paused;
    _ticker?.cancel();
    _ticker = null;
    _sensors.setPaused(true);
    _speedMs = 0;
    _lastPoint = null; // al reanudar no se cuenta el salto de la pausa
    _notify(force: true);

    // Ambos se invocan juntos: cada uno suelta su suscripción de inmediato.
    await Future.wait([
      _location.stopTracking(),
      _sensors.stopMotionSensors(),
    ]);
  }

  Future<void> _doResume() async {
    if (_status != WorkoutStatus.paused) return;
    _autoPaused = false;
    _status = WorkoutStatus.running;
    _sw.start();
    _lastElapsed = _sw.elapsed;
    _sensors.setPaused(false);
    _sensors.startMotionSensors();
    _startTicker();
    _notify(force: true);

    _locationGranted = await _permissions.isGranted(AppPermission.location);
    await _startGps();
  }

  // ---------- Fin ----------

  /// Detiene todo y guarda. Devuelve el entrenamiento guardado, o null si
  /// fue demasiado corto o falló (revisa [status] y [notice]).
  Future<WorkoutModel?> finishAndSave() async {
    if (!isActive) return null;
    if (_status == WorkoutStatus.running) _accumulate();
    await _teardown();

    if (_sw.elapsed.inSeconds < _minSaveSeconds) {
      _status = WorkoutStatus.discarded;
      _notice = 'El entrenamiento duró menos de $_minSaveSeconds s y no se guardó.';
      _notify(force: true);
      return null;
    }

    _status = WorkoutStatus.saving;
    _notify(force: true);
    return _persist();
  }

  Future<WorkoutModel?> retrySave() async {
    if (_status != WorkoutStatus.saveFailed) return null;
    _status = WorkoutStatus.saving;
    _notify(force: true);
    return _persist();
  }

  /// Sale sin guardar.
  Future<void> discard() async {
    if (!isActive) return;
    await _teardown();
    _status = WorkoutStatus.discarded;
    _notify(force: true);
  }

  Future<WorkoutModel?> _persist() async {
    try {
      final id = await _repository.insert(_buildModel());
      final saved = _buildModel(id: id);
      _status = WorkoutStatus.saved;
      unawaited(
        _notifications.showWorkoutSaved(
          title: 'Entrenamiento guardado',
          body: '${Formatters.distance(saved.distanceM)} · '
              '${Formatters.integer(saved.steps)} pasos · '
              '${Formatters.duration(saved.duration)}',
        ),
      );
      _notify(force: true);
      return saved;
    } catch (_) {
      _status = WorkoutStatus.saveFailed;
      _notice = 'No se pudo guardar el entrenamiento. Intenta de nuevo.';
      _notify(force: true);
      return null;
    }
  }

  /// Libera todo: temporizador, GPS (y su notificación), sensores y observador.
  Future<void> _teardown() async {
    _ticker?.cancel();
    _ticker = null;
    _sw.stop();
    _endedAt = DateTime.now();
    _finalSteps = _sensors.steps;
    _background.detach();
    await _location.stopTracking();
    await _sensors.dispose();
  }

  WorkoutModel _buildModel({int? id}) {
    final seconds = _sw.elapsed.inSeconds;
    final started = _startedAt ?? DateTime.now().subtract(_sw.elapsed);
    final ended = _endedAt ?? DateTime.now();
    return WorkoutModel(
      id: id,
      userId: _user.id ?? 0,
      startedAtMs: started.millisecondsSinceEpoch,
      endedAtMs: ended.millisecondsSinceEpoch,
      durationSec: seconds,
      steps: steps,
      distanceM: distanceM,
      calories: _calories,
      avgSpeedMs: FitnessCalculator.averageSpeedMs(
        distanceM,
        Duration(seconds: seconds),
      ),
      maxSpeedMs: _maxSpeedMs,
      restSec: _restMs ~/ 1000,
      walkSec: _walkMs ~/ 1000,
      jogSec: _jogMs ~/ 1000,
      route: List<RoutePoint>.of(_route),
      samples: _samplesForSave(),
    );
  }

  /// Reduce las muestras a un máximo para que el JSON no crezca sin límite.
  List<ChartSample> _samplesForSave() {
    if (_samples.length <= _maxSavedSamples) return List.of(_samples);
    final step = (_samples.length / _maxSavedSamples).ceil();
    return [
      for (var i = 0; i < _samples.length; i += step) _samples[i],
    ];
  }

  // ---------- Temporizador (4 Hz) ----------

  void _startTicker() {
    _ticker?.cancel();
    final interval = _background.isInBackground
        ? _backgroundTick
        : AppConstants.uiRefreshInterval;
    _ticker = Timer.periodic(interval, (_) => _onTick());
  }

  void _onTick() {
    if (_status != WorkoutStatus.running) return;
    _accumulate();
    _sensors.checkHealth();

    // La velocidad vuelve a 0 si no hay lecturas de GPS recientes.
    final fixAt = _lastFixAt;
    if (fixAt == null ||
        DateTime.now().difference(fixAt) > AppConstants.gpsStaleAfter) {
      _speedMs = 0;
    }

    _sampleChart();
    if (!_background.isInBackground) _notify();
  }

  /// Suma el tiempo transcurrido desde el último tick a la intensidad
  /// actual y a las calorías (MET × peso × horas).
  void _accumulate() {
    final el = _sw.elapsed;
    final dt = el - _lastElapsed;
    _lastElapsed = el;
    if (dt <= Duration.zero) return;

    final current = _effectiveIntensity();
    _intensity = current;
    final ms = dt.inMilliseconds;
    switch (current) {
      case Intensity.rest:
        _restMs += ms;
      case Intensity.walk:
        _walkMs += ms;
      case Intensity.jog:
        _jogMs += ms;
    }
    _calories += FitnessCalculator.calories(
      weightKg: _weightKg,
      met: current.met,
      duration: dt,
    );
  }

  Intensity _effectiveIntensity() {
    final motionOn =
        _sensors.motionSensorsActive && _sensors.accelerometerAvailable;
    if (motionOn) return _sensors.snapshot.intensity;
    // Respaldo: sin acelerómetro (segundo plano o sin sensor) se usa la
    // velocidad del GPS.
    if (_speedMs < _speedRestMax) return Intensity.rest;
    if (_speedMs < _speedWalkMax) return Intensity.walk;
    return Intensity.jog;
  }

  /// Una muestra por segundo para las gráficas.
  void _sampleChart() {
    final sec = _sw.elapsed.inSeconds;
    if (sec <= _lastSampleSec) return;
    _lastSampleSec = sec;
    _samples.add(
      ChartSample(
        second: sec,
        speedKmh: _speedMs * 3.6,
        intensityLevel: _intensity.level,
      ),
    );
    final from = _samples.length > AppConstants.chartMaxPoints
        ? _samples.length - AppConstants.chartMaxPoints
        : 0;
    _recent = _samples.sublist(from);
  }

  // ---------- GPS ----------

  bool get _canRecordGps =>
      !_disposed &&
          _status == WorkoutStatus.running &&
          !_background.isInBackground;

  Future<void> _startGps() async {
    if (!_canRecordGps) return;
    if (!_locationGranted) {
      _gpsProblem = GpsProblem.permission;
      _notify(force: true);
      return;
    }

    final enabled = await _location.isServiceEnabled();
    if (!_canRecordGps) return;
    if (!enabled) {
      _gpsProblem = GpsProblem.serviceOff;
      _notify(force: true);
      return;
    }

    _gpsProblem = GpsProblem.none;
    _location.startTracking(
      onFix: _onFix,
      onError: _onGpsError,
      onServiceStatus: _onServiceStatus,
    );
    _notify(force: true);
    unawaited(_quickFix());
  }

  /// Posición inicial rápida: la última conocida centra el mapa al instante
  /// y la lectura actual (con tiempo límite) fija el punto de partida.
  Future<void> _quickFix() async {
    final last = await _location.lastKnown();
    if (_disposed) return;
    if (last != null && _curLat == null) {
      _curLat = last.lat;
      _curLon = last.lon;
      _notify(force: true);
    }
    final fix = await _location.currentFix();
    if (fix != null && !_disposed && _location.isTracking) _onFix(fix);
  }

  void _onFix(GpsFix fix) {
    if (_disposed) return;
    if (!isActive) return;

    // Filtro de lecturas imprecisas.
    if (!GeoUtils.isAccurate(fix.accuracyM)) return;

    _hasFix = true;
    _gpsProblem = GpsProblem.none;
    _lastFixAt = fix.timestamp;
    _curLat = fix.lat;
    _curLon = fix.lon;

    if (_status != WorkoutStatus.running) return;

    final tsMs = fix.timestamp.millisecondsSinceEpoch;
    final last = _lastPoint;
    if (last == null) {
      _addPoint(fix, tsMs);
      return;
    }

    final meters =
    GeoUtils.distanceMeters(last.lat, last.lon, fix.lat, fix.lon);
    final elapsed = Duration(milliseconds: tsMs - last.timestampMs);

    // Movimiento menor al ruido del GPS: no se suma, pero la velocidad baja.
    if (meters < AppConstants.gpsMinSegmentM) {
      _speedMs = fix.speedMs;
      return;
    }
    // Salto imposible: se descarta.
    if (!GeoUtils.isPlausibleMove(meters: meters, elapsed: elapsed)) return;

    _gpsDistanceM += meters;
    final raw =
    fix.speedMs > 0 ? fix.speedMs : GeoUtils.speedMs(meters, elapsed);
    _speedMs = _speedMs * 0.4 + raw * 0.6;
    if (_speedMs > _maxSpeedMs) _maxSpeedMs = _speedMs;
    _addPoint(fix, tsMs);
  }

  void _addPoint(GpsFix fix, int tsMs) {
    final point = RoutePoint(lat: fix.lat, lon: fix.lon, timestampMs: tsMs);
    _route.add(point);
    _lastPoint = point;
    _routeVersion++;
  }

  void _onGpsError(Object error) {
    unawaited(_handleGpsError());
  }

  Future<void> _handleGpsError() async {
    final enabled = await _location.isServiceEnabled();
    if (_disposed) return;
    _gpsProblem = enabled ? GpsProblem.error : GpsProblem.serviceOff;
    _notify(force: true);
  }

  void _onServiceStatus(bool enabled) {
    if (_disposed) return;
    if (!enabled) {
      _gpsProblem = GpsProblem.serviceOff;
      _notice = 'El GPS se apagó. Actívalo para seguir registrando la ruta.';
      _notify(force: true);
    } else if (_gpsProblem == GpsProblem.serviceOff) {
      unawaited(retryGps());
    }
  }

  /// Reinicia el GPS (botón "Reintentar" o al reactivar la ubicación).
  Future<void> retryGps() async {
    await _location.stopTracking();
    _locationGranted = await _permissions.isGranted(AppPermission.location);
    await _startGps();
  }

  Future<void> openLocationSettings() => _location.openLocationSettings();
  Future<bool> openAppSettings() => _permissions.openSettings();

  // ---------- Ciclo de vida de la app ----------

  void _onBackground() {
    if (_status != WorkoutStatus.running) return;
    final gpsOk = _location.isTracking && _gpsProblem == GpsProblem.none;
    if (gpsOk) {
      // El GPS y su servicio en primer plano siguen; se ahorra batería.
      unawaited(_sensors.stopMotionSensors());
      _startTicker();
    } else {
      // Sin GPS no hay nada que registrar en segundo plano: se pausa todo.
      _autoPaused = true;
      _notice =
      'Sin GPS en segundo plano: el entrenamiento se pausó y seguirá al volver.';
      unawaited(_doPause());
    }
  }

  void _onForeground() {
    if (_disposed) return;
    if (_status == WorkoutStatus.running) {
      _sensors.startMotionSensors();
      _startTicker();
      unawaited(_ensureGps());
    } else if (_status == WorkoutStatus.paused && _autoPaused) {
      unawaited(_doResume());
    }
    _notify(force: true);
  }

  Future<void> _ensureGps() async {
    if (_location.isTracking) return;
    _locationGranted = await _permissions.isGranted(AppPermission.location);
    await _startGps();
  }

  // ---------- Utilidades ----------

  /// Notificación limitada: la UI se refresca como máximo ~4 a 5 veces por
  /// segundo (RNF-03). Los cambios de estado usan `force`.
  void _notify({bool force = false}) {
    if (_disposed) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastNotify) < _notifyGap) return;
    _lastNotify = now;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _ticker = null;
    _background.detach();
    unawaited(_location.stopTracking());
    unawaited(_sensors.dispose());
    super.dispose();
  }
}
