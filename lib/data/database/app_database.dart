import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';

/// Acceso único a SQLite (patrón singleton).
/// Los repositorios piden la base de datos aquí; nadie más la abre.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getDatabasesPath();
    final path = p.join(dir, AppConstants.dbName);
    final db = await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
    _db = db;
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE COLLATE NOCASE,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        weight_kg REAL,
        height_cm REAL,
        age INTEGER,
        sex TEXT,
        daily_goal INTEGER NOT NULL DEFAULT 10000,
        biometric_enabled INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER NOT NULL,
        duration_sec INTEGER NOT NULL,
        steps INTEGER NOT NULL,
        distance_m REAL NOT NULL,
        calories REAL NOT NULL,
        avg_speed_ms REAL NOT NULL,
        max_speed_ms REAL NOT NULL,
        rest_sec INTEGER NOT NULL DEFAULT 0,
        walk_sec INTEGER NOT NULL DEFAULT 0,
        jog_sec INTEGER NOT NULL DEFAULT 0,
        route_json TEXT NOT NULL,
        samples_json TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_workouts_user_date ON workouts (user_id, started_at DESC)',
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}