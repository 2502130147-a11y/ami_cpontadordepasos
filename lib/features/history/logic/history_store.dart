import 'package:flutter/foundation.dart';

import '../data/training.dart';
import '../data/training_repository.dart';

/// Historial en memoria + estadísticas para el inicio.
class HistoryStore extends ChangeNotifier {
  HistoryStore([TrainingRepository? repo]) : _repo = repo ?? TrainingRepository();
  final TrainingRepository _repo;

  List<Training> items = [];
  bool loading = true;

  Future<void> load() async {
    try {
      items = await _repo.all();
    } catch (_) {
      items = [];
    }
    loading = false;
    notifyListeners();
  }

  Future<Training> add(Training t) async {
    final id = await _repo.insert(t);
    final saved = t.withId(id);
    items = [saved, ...items];
    notifyListeners();
    return saved;
  }

  Future<void> remove(int id) async {
    await _repo.delete(id);
    items = items.where((t) => t.id != id).toList();
    notifyListeners();
  }

  Future<void> clear() async {
    await _repo.clear();
    items = [];
    notifyListeners();
  }

  /// Se usa cuando se elimina la cuenta (la BD ya se vació).
  void forget() {
    items = [];
    notifyListeners();
  }

  // ------------------------------------------------------------ estadísticas
  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime get weekStart {
    final today = _day(DateTime.now());
    return DateTime(today.year, today.month, today.day - (today.weekday - 1));
  }

  Iterable<Training> get thisWeek => items.where((t) => !t.startedAt.isBefore(weekStart));

  int get weekSteps => thisWeek.fold<int>(0, (a, t) => a + t.steps);
  double get weekKm => thisWeek.fold<double>(0, (a, t) => a + t.km);
  int get weekActiveSec => thisWeek.fold<int>(0, (a, t) => a + t.activeSec);

  /// Pasos por día de la semana actual (lunes..domingo).
  List<int> get weekDailySteps {
    final out = List<int>.filled(7, 0);
    for (final t in thisWeek) {
      out[t.startedAt.weekday - 1] += t.steps;
    }
    return out;
  }

  Iterable<Training> get today {
    final d = _day(DateTime.now());
    return items.where((t) => _day(t.startedAt) == d);
  }

  int get todaySteps => today.fold<int>(0, (a, t) => a + t.steps);
  double get todayKm => today.fold<double>(0, (a, t) => a + t.km);
  int get todayActiveMin => (today.fold<int>(0, (a, t) => a + t.activeSec) / 60).round();

  int get totalSteps => items.fold<int>(0, (a, t) => a + t.steps);
  double get totalKm => items.fold<double>(0, (a, t) => a + t.km);
  int get totalSec => items.fold<int>(0, (a, t) => a + t.durationSec);

  /// Días seguidos (hasta hoy o ayer) con al menos un entrenamiento.
  int get streak {
    if (items.isEmpty) return 0;
    final days = items.map((t) => _day(t.startedAt)).toSet();
    var cursor = _day(DateTime.now());
    if (!days.contains(cursor)) cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    var n = 0;
    while (days.contains(cursor)) {
      n++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return n;
  }
}
