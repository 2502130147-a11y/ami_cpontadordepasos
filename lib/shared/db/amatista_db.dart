import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base de datos SQLite local (una sola instancia para toda la app).
///
/// Tablas:
///  - account: perfil del dueño del teléfono (una sola fila, id = 1).
///  - trainings: historial de entrenamientos (fecha, duración, pasos, ruta…).
class AmatistaDb {
  AmatistaDb._();
  static final AmatistaDb instance = AmatistaDb._();

  static const _fileName = 'amatista_v1.db';
  static const _version = 2; // v2: plantilla facial (face_template)

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _fileName);
    return openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE account (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            name TEXT NOT NULL,
            username TEXT NOT NULL,
            pass_hash TEXT NOT NULL,
            salt TEXT NOT NULL,
            weight_kg REAL NOT NULL,
            height_cm REAL NOT NULL,
            sex TEXT NOT NULL,
            weekly_steps_goal INTEGER NOT NULL,
            weekly_km_goal REAL NOT NULL,
            access_mode TEXT NOT NULL,
            finger_linked INTEGER NOT NULL DEFAULT 0,
            face_linked INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            face_template TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE trainings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            started_at INTEGER NOT NULL,
            duration_sec INTEGER NOT NULL,
            steps INTEGER NOT NULL,
            distance_m REAL NOT NULL,
            kcal REAL NOT NULL,
            avg_kmh REAL NOT NULL,
            max_kmh REAL NOT NULL,
            rest_sec INTEGER NOT NULL,
            walk_sec INTEGER NOT NULL,
            jog_sec INTEGER NOT NULL,
            turns INTEGER NOT NULL,
            max_tilt REAL NOT NULL,
            peak_angular REAL NOT NULL,
            route TEXT NOT NULL,
            series TEXT NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_trainings_date ON trainings(started_at)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE account ADD COLUMN face_template TEXT');
        }
      },
    );
  }
}
