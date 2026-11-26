import '../../../shared/db/amatista_db.dart';
import 'training.dart';

/// Acceso a la tabla `trainings` (patrón repositorio).
class TrainingRepository {
  TrainingRepository([AmatistaDb? db]) : _db = db ?? AmatistaDb.instance;
  final AmatistaDb _db;

  Future<List<Training>> all() async {
    final db = await _db.db;
    final rows = await db.query('trainings', orderBy: 'started_at DESC');
    return rows.map(Training.fromRow).toList();
  }

  Future<int> insert(Training t) async {
    final db = await _db.db;
    return db.insert('trainings', t.toRow());
  }

  Future<void> delete(int id) async {
    final db = await _db.db;
    await db.delete('trainings', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clear() async {
    final db = await _db.db;
    await db.delete('trainings');
  }
}
