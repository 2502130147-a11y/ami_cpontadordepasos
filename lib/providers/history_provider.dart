import 'package:flutter/foundation.dart';

import '../data/models/workout_model.dart';
import '../data/repositories/workout_repository.dart';

/// Historial de entrenamientos del usuario.
class HistoryProvider extends ChangeNotifier {
  HistoryProvider({WorkoutRepository? repository})
      : _repo = repository ?? WorkoutRepository();

  final WorkoutRepository _repo;

  List<WorkoutModel> _items = const [];
  bool _loaded = false;
  String? _error;

  List<WorkoutModel> get items => _items;

  /// Falso hasta que termina la primera carga (la UI muestra un spinner).
  bool get loaded => _loaded;
  String? get error => _error;
  bool get isEmpty => _items.isEmpty;

  Future<void> load(int userId) async {
    try {
      _items = await _repo.getAll(userId);
      _error = null;
    } catch (_) {
      _error = 'No se pudo cargar el historial';
    }
    _loaded = true;
    notifyListeners();
  }

  Future<bool> delete(WorkoutModel workout) async {
    final id = workout.id;
    if (id == null) return false;
    try {
      await _repo.delete(id);
      _items = _items.where((w) => w.id != id).toList();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Al cerrar sesión: vacía todo.
  void reset() {
    _items = const [];
    _loaded = false;
    _error = null;
    notifyListeners();
  }
}