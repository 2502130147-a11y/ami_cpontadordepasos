import 'package:flutter/foundation.dart';

import '../core/utils/formatters.dart';
import '../data/models/workout_model.dart';
import '../data/repositories/workout_repository.dart';

/// Datos del dashboard: resumen de hoy, gráfica semanal y último entrenamiento.
class DashboardProvider extends ChangeNotifier {
  DashboardProvider({WorkoutRepository? repository})
      : _repo = repository ?? WorkoutRepository();

  final WorkoutRepository _repo;

  bool _loaded = false;
  String? _error;
  int _todaySteps = 0;
  double _todayDistanceM = 0;
  double _todayCalories = 0;
  int _todayDurationSec = 0;
  int _todayWorkouts = 0;
  List<DailySteps> _weekly = const [];
  WorkoutModel? _latest;

  bool get loaded => _loaded;
  String? get error => _error;

  int get todaySteps => _todaySteps;
  double get todayDistanceM => _todayDistanceM;
  double get todayCalories => _todayCalories;
  Duration get todayDuration => Duration(seconds: _todayDurationSec);
  int get todayWorkouts => _todayWorkouts;

  List<DailySteps> get weekly => _weekly;
  WorkoutModel? get latest => _latest;

  int get weeklyTotal => _weekly.fold(0, (sum, d) => sum + d.steps);

  int get weeklyAverage =>
      _weekly.isEmpty ? 0 : (weeklyTotal / _weekly.length).round();

  Future<void> load(int userId) async {
    try {
      final today = Formatters.startOfDay(DateTime.now());
      final tomorrow = today.add(const Duration(days: 1));

      final todays = await _repo.getBetween(userId, today, tomorrow);
      _todayWorkouts = todays.length;
      _todaySteps = todays.fold(0, (s, w) => s + w.steps);
      _todayDistanceM = todays.fold(0.0, (s, w) => s + w.distanceM);
      _todayCalories = todays.fold(0.0, (s, w) => s + w.calories);
      _todayDurationSec = todays.fold(0, (s, w) => s + w.durationSec);

      _weekly = await _repo.stepsPerDay(userId, days: 7);
      _latest = await _repo.getLatest(userId);
      _error = null;
    } catch (_) {
      _error = 'No se pudo cargar el dashboard';
    }
    _loaded = true;
    notifyListeners();
  }

  /// Al cerrar sesión: vacía todo.
  void reset() {
    _loaded = false;
    _error = null;
    _todaySteps = 0;
    _todayDistanceM = 0;
    _todayCalories = 0;
    _todayDurationSec = 0;
    _todayWorkouts = 0;
    _weekly = const [];
    _latest = null;
    notifyListeners();
  }
}