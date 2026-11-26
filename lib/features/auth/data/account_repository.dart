import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../../../shared/db/amatista_db.dart';
import 'account.dart';

/// Acceso a la tabla `account` (patrón repositorio).
class AccountRepository {
  AccountRepository([AmatistaDb? db]) : _db = db ?? AmatistaDb.instance;
  final AmatistaDb _db;

  Future<Account?> load() async {
    final db = await _db.db;
    final rows = await db.query('account', where: 'id = 1', limit: 1);
    return rows.isEmpty ? null : Account.fromRow(rows.first);
  }

  Future<void> save(Account a) async {
    final db = await _db.db;
    await db.insert('account', a.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Borra el perfil y todo el historial.
  Future<void> wipe() async {
    final db = await _db.db;
    await db.transaction((txn) async {
      await txn.delete('trainings');
      await txn.delete('account');
    });
  }

  // ---- Contraseña (SHA-256 con sal aleatoria) ----
  static String newSalt() {
    final r = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  static String hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt::$password')).toString();
}
