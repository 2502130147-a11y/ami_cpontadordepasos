import 'package:flutter/foundation.dart';

import '../data/models/user_model.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';

/// Estado de la sesión. La sesión vive solo en memoria: al cerrar la app
/// siempre se vuelve a pedir huella o contraseña.
class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? auth, BiometricService? biometric})
      : _auth = auth ?? AuthService(),
        _biometric = biometric ?? BiometricService();

  final AuthService _auth;
  final BiometricService _biometric;

  UserModel? _user;
  UserModel? _biometricUser;
  String? _lastUsername;
  BiometricAvailability _availability = BiometricAvailability.notSupported;
  bool _busy = false;
  bool _loaded = false;

  UserModel? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get busy => _busy;

  /// ¿Ya se consultó el estado de la huella en este teléfono?
  bool get loaded => _loaded;

  String? get lastUsername => _lastUsername;

  /// El teléfono tiene lector y al menos una huella registrada.
  bool get deviceHasBiometric =>
      _availability == BiometricAvailability.available;

  BiometricAvailability get availability => _availability;

  /// Hay un usuario con la huella activada en este teléfono.
  bool get biometricActivatedOnDevice => _biometricUser != null;

  /// Se puede iniciar sesión ahora mismo con huella.
  bool get canLoginWithBiometric =>
      deviceHasBiometric && biometricActivatedOnDevice;

  /// ¿El usuario actual tiene la huella activada?
  bool get currentUserBiometricEnabled => _user?.biometricEnabled ?? false;

  /// Consulta la huella y el último usuario. Se llama al abrir el login.
  Future<void> loadLoginOptions() async {
    _availability = await _biometric.availability();
    _biometricUser = await _auth.biometricCandidate();
    _lastUsername = await _auth.lastUsername();
    _loaded = true;
    notifyListeners();
  }

  // ---------- Contraseña ----------

  /// Devuelve null si entró, o el mensaje de error.
  Future<String?> login(String username, String password) async {
    _setBusy(true);
    try {
      final user = await _auth.login(username, password);
      if (user == null) return 'Usuario o contraseña incorrectos';
      _user = user;
      return null;
    } catch (_) {
      return 'No se pudo iniciar sesión. Intenta de nuevo.';
    } finally {
      _setBusy(false);
    }
  }

  /// Devuelve null si se creó la cuenta, o el mensaje de error.
  Future<String?> register({
    required String name,
    required String username,
    required String password,
    required double weightKg,
    required double heightCm,
    required int age,
    required Sex sex,
    required int dailyGoal,
  }) async {
    _setBusy(true);
    try {
      final result = await _auth.register(
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
      if (user == null) return result.error ?? 'No se pudo crear la cuenta';
      _user = user;
      return null;
    } catch (_) {
      return 'No se pudo crear la cuenta. Intenta de nuevo.';
    } finally {
      _setBusy(false);
    }
  }

  // ---------- Huella ----------

  /// Pide la huella y, si es correcta, abre la sesión del usuario que la activó.
  /// La pantalla muestra la alerta de éxito o de fallo con `result.message`.
  Future<BiometricResult> loginWithBiometric() async {
    final candidate = _biometricUser;
    if (candidate == null || candidate.id == null) {
      return const BiometricResult(
        BiometricOutcome.error,
        'Aún no activas la huella. Inicia con tu contraseña y actívala en tu perfil.',
      );
    }

    final result = await _biometric.authenticate(
      reason: 'Verifica tu huella para entrar a FitPulse',
    );
    if (!result.isSuccess) return result;

    final fresh = await _auth.reload(candidate.id!);
    if (fresh == null) {
      _biometricUser = null;
      notifyListeners();
      return const BiometricResult(
        BiometricOutcome.error,
        'La cuenta ya no existe en este teléfono.',
      );
    }
    _user = fresh;
    notifyListeners();
    return result;
  }

  /// Pide la huella para confirmarla y la activa para el usuario actual.
  Future<BiometricResult> enableBiometric() async {
    final current = _user;
    if (current == null) {
      return const BiometricResult(
        BiometricOutcome.error,
        'No hay una sesión activa.',
      );
    }
    final result = await _biometric.authenticate(
      reason: 'Confirma tu huella para activarla en FitPulse',
    );
    if (!result.isSuccess) return result;

    await _auth.enableBiometric(current);
    final updated = current.copyWith(biometricEnabled: true);
    _user = updated;
    _biometricUser = updated;
    notifyListeners();
    return result;
  }

  Future<void> disableBiometric() async {
    final current = _user;
    if (current == null) return;
    await _auth.disableBiometric(current);
    _user = current.copyWith(biometricEnabled: false);
    _biometricUser = null;
    notifyListeners();
  }

  // ---------- Perfil y sesión ----------

  /// Guarda el perfil y actualiza el usuario en memoria.
  Future<void> updateProfile(UserModel updated) async {
    await _auth.updateProfile(updated);
    _user = updated;
    notifyListeners();
  }

  Future<void> logout() async {
    _user = null;
    notifyListeners();
    await loadLoginOptions();
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}