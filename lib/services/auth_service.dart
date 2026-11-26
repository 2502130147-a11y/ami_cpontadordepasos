import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../data/models/user_model.dart';
import '../data/repositories/user_repository.dart';

/// Lógica de acceso. La SESIÓN NO SE GUARDA: al abrir la app siempre se pide
/// huella o contraseña. Solo se recuerda (en preferencias) qué usuario activó
/// la huella en este teléfono y cuál fue el último usuario escrito.
class AuthService {
  AuthService({UserRepository? users}) : _users = users ?? UserRepository();

  final UserRepository _users;

  Future<UserModel?> login(String username, String password) async {
    final user = await _users.verifyCredentials(username, password);
    if (user != null) await _rememberUsername(user.username);
    return user;
  }

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
    final result = await _users.register(
      name: name,
      username: username,
      password: password,
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      sex: sex,
      dailyGoal: dailyGoal,
    );
    final user = result.user;
    if (user != null) await _rememberUsername(user.username);
    return result;
  }

  // ---------- Huella ----------

  /// Usuario que activó la huella en este teléfono (o null).
  Future<UserModel?> biometricCandidate() async {
    final prefs = await _prefs();
    if (prefs == null) return null;
    final id = prefs.getInt(AppConstants.prefBiometricUserId);
    if (id == null) return null;
    final user = await _users.findById(id);
    if (user == null || !user.biometricEnabled) {
      await prefs.remove(AppConstants.prefBiometricUserId);
      return null;
    }
    return user;
  }

  /// Activa la huella para [user]. Solo un usuario por teléfono: si otro la
  /// tenía, se le desactiva.
  Future<void> enableBiometric(UserModel user) async {
    final id = user.id;
    if (id == null) return;
    final prefs = await _prefs();
    final previous = prefs?.getInt(AppConstants.prefBiometricUserId);
    if (previous != null && previous != id) {
      await _users.setBiometricEnabled(previous, false);
    }
    await _users.setBiometricEnabled(id, true);
    await prefs?.setInt(AppConstants.prefBiometricUserId, id);
  }

  Future<void> disableBiometric(UserModel user) async {
    final id = user.id;
    if (id == null) return;
    await _users.setBiometricEnabled(id, false);
    final prefs = await _prefs();
    if (prefs?.getInt(AppConstants.prefBiometricUserId) == id) {
      await prefs?.remove(AppConstants.prefBiometricUserId);
    }
  }

  // ---------- Perfil ----------

  Future<UserModel?> reload(int id) => _users.findById(id);

  Future<void> updateProfile(UserModel user) => _users.updateProfile(user);

  Future<String?> lastUsername() async {
    final prefs = await _prefs();
    return prefs?.getString(AppConstants.prefLastUsername);
  }

  // ---------- Internos ----------

  Future<void> _rememberUsername(String username) async {
    final prefs = await _prefs();
    await prefs?.setString(AppConstants.prefLastUsername, username);
  }

  Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }
}