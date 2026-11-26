import '../database/app_database.dart';
import '../models/workout_model.dart';

/// Pasos totales de un día (para la gráfica semanal).
class DailySteps {
  const DailySteps(this.day, this.steps);
  final DateTime day;
  final int steps;
}

/// Totales acumulados de todos los entrenamientos de un usuario.
class WorkoutTotals {
  const WorkoutTotals({
    required this.count,
    required this.steps,
    required this.distanceM,
    required this.calories,
    required this.durationSec,
  });

  const WorkoutTotals.empty()
      : count = 0,
        steps = 0,
        distanceM = 0,
        calories = 0,
        durationSec = 0;

  final int count;
  final int steps;
  final double distanceM;
  final double calories;
  final int durationSec;
}

/// Única puerta de acceso a la tabla `workouts`.
class WorkoutRepository {
  WorkoutRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<int> insert(WorkoutModel workout) async {
    final db = await _database.database;
    return db.insert('workouts', workout.toMap());
  }

  /// Historial completo, del más reciente al más antiguo.
  Future<List<WorkoutModel>> getAll(int userId) async {
    final db = await _database.database;
    final rows = await db.query(
      'workouts',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'started_at DESC',
    );
    return rows.map(WorkoutModel.fromMap).toList();
  }

  Future<WorkoutModel?> getById(int id) async {
    final db = await _database.database;
    final rows = await db.query(
      'workouts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : WorkoutModel.fromMap(rows.first);
  }

  Future<WorkoutModel?> getLatest(int userId) async {
    final db = await _database.database;
    final rows = await db.query(
      'workouts',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : WorkoutModel.fromMap(rows.first);
  }

  Future<void> delete(int id) async {
    final db = await _database.database;
    await db.delete('workouts', where: 'id = ?', whereArgs: [id]);
  }

  /// Entrenamientos que empezaron en [from, to).
  Future<List<WorkoutModel>> getBetween(
      int userId,
      DateTime from,
      DateTime to,
      ) async {
    final db = await _database.database;
    final rows = await db.query(
      'workouts',
      where: 'user_id = ? AND started_at >= ? AND started_at < ?',
      whereArgs: [
        userId,
        from.millisecondsSinceEpoch,
        to.millisecondsSinceEpoch,
      ],
      orderBy: 'started_at DESC',
    );
    return rows.map(WorkoutModel.fromMap).toList();
  }

  /// Pasos por día de los últimos [days] días (incluye hoy).
  /// Los días sin entrenamientos salen con 0.
  Future<List<DailySteps>> stepsPerDay(int userId, {int days = 7}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = today.subtract(Duration(days: days - 1));
    final end = today.add(const Duration(days: 1));

    final db = await _database.database;
    // Solo las columnas necesarias: no carga las rutas pesadas.
    final rows = await db.query(
      'workouts',
      columns: ['started_at', 'steps'],
      where: 'user_id = ? AND started_at >= ? AND started_at < ?',
      whereArgs: [
        userId,
        first.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
    );

    final byDay = <int, int>{};
    for (final r in rows) {
      final d = DateTime.fromMillisecondsSinceEpoch(
        (r['started_at'] as num).toInt(),
      );
      final key = DateTime(d.year, d.month, d.day).millisecondsSinceEpoch;
      byDay[key] = (byDay[key] ?? 0) + (r['steps'] as num).toInt();
    }

    return List.generate(days, (i) {
      final day = first.add(Duration(days: i));
      return DailySteps(day, byDay[day.millisecondsSinceEpoch] ?? 0);
    });
  }

  Future<WorkoutTotals> totals(int userId) async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS c,
             COALESCE(SUM(steps), 0) AS s,
             COALESCE(SUM(distance_m), 0) AS d,
             COALESCE(SUM(calories), 0) AS k,
             COALESCE(SUM(duration_sec), 0) AS t
      FROM workouts WHERE user_id = ?
      ''',
      [userId],
    );
    if (rows.isEmpty) return const WorkoutTotals.empty();
    final r = rows.first;
    return WorkoutTotals(
      count: (r['c'] as num).toInt(),
      steps: (r['s'] as num).toInt(),
      distanceM: (r['d'] as num).toDouble(),
      calories: (r['k'] as num).toDouble(),
      durationSec: (r['t'] as num).toInt(),
    );
  }
}