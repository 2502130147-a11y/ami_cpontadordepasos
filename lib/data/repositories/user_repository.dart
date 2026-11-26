import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/user_model.dart';

/// Resultado de un registro: o hay usuario, o hay un mensaje de error.
class RegisterResult {
  const RegisterResult.ok(this.user) : error = null;
  const RegisterResult.fail(this.error) : user = null;
  final UserModel? user;
  final String? error;
  bool get isOk => user != null;
}

/// Única puerta de acceso a la tabla `users`.
/// Aquí también vive el hash SHA-256 con sal.
class UserRepository {
  UserRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  // ---------- Hash de contraseñas ----------

  /// Sal aleatoria de 16 bytes en Base64.
  static String generateSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// SHA-256 de (sal + contraseña), en hexadecimal.
  static String hashPassword(String password, String salt) {
    return sha256.convert(utf8.encode('$salt$password')).toString();
  }

  /// Comparación en tiempo constante (evita ataques por tiempo).
  static bool _safeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  // ---------- Registro y acceso ----------

  Future<RegisterResult> register({
    required String name,
    required String username,
    required String password,
    required double weightKg,
    required double heightCm,
    required int age,
    required Sex sex,
    required int dailyGoal,
  }) async {
    try {
      final db = await _database.database;
      final salt = generateSalt();
      final user = UserModel(
        name: name.trim(),
        username: username.trim(),
        passwordHash: hashPassword(password, salt),
        salt: salt,
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        sex: sex,
        dailyGoal: dailyGoal,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      final id = await db.insert(
        'users',
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return RegisterResult.ok(user.copyWith(id: id));
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        return const RegisterResult.fail('Ese usuario ya existe');
      }
      return const RegisterResult.fail('No se pudo guardar la cuenta');
    } catch (_) {
      return const RegisterResult.fail('Ocurrió un error inesperado');
    }
  }

  Future<UserModel?> findByUsername(String username) async {
    final db = await _database.database;
    final rows = await db.query(
      'users',
      where: 'username = ? COLLATE NOCASE',
      whereArgs: [username.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : UserModel.fromMap(rows.first);
  }

  Future<UserModel?> findById(int id) async {
    final db = await _database.database;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : UserModel.fromMap(rows.first);
  }

  /// Devuelve el usuario si usuario y contraseña son correctos; si no, null.
  Future<UserModel?> verifyCredentials(String username, String password) async {
    final user = await findByUsername(username);
    if (user == null) return null;
    final hash = hashPassword(password, user.salt);
    return _safeEquals(hash, user.passwordHash) ? user : null;
  }

  // ---------- Perfil ----------

  Future<void> updateProfile(UserModel user) async {
    if (user.id == null) return;
    final db = await _database.database;
    await db.update(
      'users',
      {
        'name': user.name,
        'weight_kg': user.weightKg,
        'height_cm': user.heightCm,
        'age': user.age,
        'sex': user.sex?.name,
        'daily_goal': user.dailyGoal,
      },
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<void> setBiometricEnabled(int userId, bool enabled) async {
    final db = await _database.database;
    await db.update(
      'users',
      {'biometric_enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
}