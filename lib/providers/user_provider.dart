import 'package:flutter/foundation.dart';

import '../core/utils/fitness_calculator.dart';
import '../data/models/user_model.dart';
import '../data/repositories/workout_repository.dart';
import 'auth_provider.dart';

/// Perfil, IMC, zancada y totales. Lee el usuario de [AuthProvider] y
/// avisa a la UI cuando este cambia.
class UserProvider extends ChangeNotifier {
  UserProvider({required AuthProvider auth, WorkoutRepository? workouts})
      : _auth = auth,
        _workouts = workouts ?? WorkoutRepository() {
    _auth.addListener(_onAuthChanged);
  }

  final AuthProvider _auth;
  final WorkoutRepository _workouts;

  WorkoutTotals _totals = const WorkoutTotals.empty();

  UserModel? get user => _auth.user;
  WorkoutTotals get totals => _totals;

  bool get hasBodyData => user?.hasBodyData ?? false;

  /// IMC, o null si la cuenta aún no tiene peso y estatura.
  double? get bmi {
    final u = user;
    if (u == null || !u.hasBodyData) return null;
    return FitnessCalculator.bmi(u.weightKg!, u.heightCm!);
  }

  BmiCategory? get bmiCategory {
    final value = bmi;
    return value == null ? null : FitnessCalculator.bmiCategory(value);
  }

  ({double min, double max})? get healthyRange {
    final u = user;
    if (u == null || !u.hasBodyData) return null;
    return FitnessCalculator.healthyWeightRange(u.heightCm!);
  }

  /// Zancada en metros, o null si no hay estatura.
  double? get strideMeters {
    final u = user;
    if (u == null || !u.hasBodyData) return null;
    return FitnessCalculator.strideMeters(u.heightCm!);
  }

  Future<void> loadTotals() async {
    final id = user?.id;
    if (id == null) return;
    try {
      _totals = await _workouts.totals(id);
    } catch (_) {
      _totals = const WorkoutTotals.empty();
    }
    notifyListeners();
  }

  /// Guarda los datos del perfil. Devuelve null si salió bien, o el error.
  Future<String?> saveProfile({
    required String name,
    required double weightKg,
    required double heightCm,
    required int age,
    required Sex sex,
    required int dailyGoal,
  }) async {
    final current = user;
    if (current == null) return 'No hay una sesión activa';
    try {
      await _auth.updateProfile(
        current.copyWith(
          name: name.trim(),
          weightKg: weightKg,
          heightCm: heightCm,
          age: age,
          sex: sex,
          dailyGoal: dailyGoal,
        ),
      );
      return null;
    } catch (_) {
      return 'No se pudieron guardar los cambios';
    }
  }

  /// Se llama al cerrar sesión para no mostrar datos del usuario anterior.
  void reset() {
    _totals = const WorkoutTotals.empty();
    notifyListeners();
  }

  void _onAuthChanged() => notifyListeners();

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}