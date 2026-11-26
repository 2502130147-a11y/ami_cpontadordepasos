import 'package:flutter/foundation.dart';

import '../data/account.dart';
import '../data/account_repository.dart';
import '../data/biometric_gateway.dart';
import '../data/face_signature.dart';

enum AuthStatus { loading, noAccount, enrolling, locked, unlocked }

/// Estado de la sesión: registro, vinculación biométrica y desbloqueo.
class AuthStore extends ChangeNotifier {
  AuthStore({AccountRepository? repo, BiometricGateway? bio})
      : _repo = repo ?? AccountRepository(),
        _bio = bio ?? BiometricGateway();

  final AccountRepository _repo;
  final BiometricGateway _bio;

  AuthStatus status = AuthStatus.loading;
  Account? account;
  BioSupport support = BioSupport.none;

  /// Pasos biométricos ya superados en el desbloqueo actual.
  final Set<BioKind> passed = {};
  bool lockedOut = false;
  bool busy = false;
  int _faceFails = 0;

  Future<void> init() async {
    support = await _bio.probe();
    try {
      account = await _repo.load();
    } catch (_) {
      account = null;
    }
    status = account == null ? AuthStatus.noAccount : AuthStatus.locked;
    notifyListeners();
  }

  Future<void> refreshSupport() async {
    support = await _bio.probe();
    notifyListeners();
  }

  // ------------------------------------------------------------ registro
  Future<void> register({
    required String name,
    required String username,
    required String password,
    required double weightKg,
    required double heightCm,
    required String sex,
  }) async {
    final salt = AccountRepository.newSalt();
    final acc = Account(
      name: name.trim(),
      username: username.trim(),
      passHash: AccountRepository.hash(password, salt),
      salt: salt,
      weightKg: weightKg,
      heightCm: heightCm,
      sex: sex,
      weeklyStepsGoal: 35000,
      weeklyKmGoal: 20,
      accessMode: AccessMode.dual,
      fingerLinked: false,
      faceLinked: false,
      createdAt: DateTime.now(),
    );
    await _repo.save(acc);
    account = acc;
    status = AuthStatus.enrolling;
    notifyListeners();
  }

  /// Plantilla facial guardada (null si el rostro no está registrado).
  FaceTemplate? get faceTemplate => FaceTemplate.tryDecode(account?.faceTemplate);

  /// Guarda el rostro registrado con la cámara.
  Future<void> saveFaceTemplate(FaceTemplate t) async {
    final acc = account;
    if (acc == null) return;
    account = acc.copyWith(faceLinked: true, faceTemplate: t.encode());
    await _repo.save(account!);
    notifyListeners();
  }

  /// Vincula (o vuelve a vincular) la huella con el diálogo del sistema.
  Future<BioOutcome> link(BioKind kind) async {
    final acc = account;
    if (acc == null) return const BioOutcome(false, 'No hay perfil.');
    busy = true;
    notifyListeners();
    final r = await _bio.verify(kind, purpose: 'vincular tu perfil');
    if (r.ok) {
      account = kind == BioKind.fingerprint
          ? acc.copyWith(fingerLinked: true)
          : acc.copyWith(faceLinked: true);
      await _repo.save(account!);
    }
    busy = false;
    notifyListeners();
    return r;
  }

  void finishEnrollment() {
    passed.clear();
    status = AuthStatus.unlocked;
    notifyListeners();
  }

  // ------------------------------------------------------------ desbloqueo
  /// Métodos que se deben superar según el modo elegido y lo vinculado.
  List<BioKind> get requiredKinds {
    final a = account;
    if (a == null) return const [];
    final wanted = switch (a.accessMode) {
      AccessMode.dual => const [BioKind.fingerprint, BioKind.face],
      AccessMode.fingerprint => const [BioKind.fingerprint],
      AccessMode.face => const [BioKind.face],
    };
    return wanted
        .where((k) => k == BioKind.fingerprint ? (a.fingerLinked && support.ready) : a.faceLinked)
        .toList();
  }

  BioKind? get nextKind {
    for (final k in requiredKinds) {
      if (!passed.contains(k)) return k;
    }
    return null;
  }

  /// La contraseña solo se permite si no hay biometría utilizable
  /// o si el sistema bloqueó la biometría por intentos fallidos.
  bool get passwordAllowed => requiredKinds.isEmpty || lockedOut;

  Future<BioOutcome> unlockStep(BioKind kind) async {
    busy = true;
    notifyListeners();
    final r = await _bio.verify(kind, purpose: 'entrar');
    busy = false;
    if (r.ok) {
      passed.add(kind);
      if (nextKind == null) {
        status = AuthStatus.unlocked;
        lockedOut = false;
      }
    } else if (r.lockedOut || r.unavailable) {
      lockedOut = true;
    }
    notifyListeners();
    return r;
  }

  /// Resultado del paso facial (se verifica en FaceScanPage con la cámara).
  /// Tras 3 fallos se habilita la contraseña de respaldo.
  void faceStepResult(bool ok) {
    if (ok) {
      _faceFails = 0;
      passed.add(BioKind.face);
      if (nextKind == null) {
        status = AuthStatus.unlocked;
        lockedOut = false;
      }
    } else if (++_faceFails >= 3) {
      lockedOut = true;
    }
    notifyListeners();
  }

  bool unlockWithPassword(String password) {
    final a = account;
    if (a == null) return false;
    if (AccountRepository.hash(password, a.salt) != a.passHash) return false;
    passed.clear();
    lockedOut = false;
    status = AuthStatus.unlocked;
    notifyListeners();
    return true;
  }

  void lock() {
    passed.clear();
    lockedOut = false;
    _faceFails = 0;
    status = account == null ? AuthStatus.noAccount : AuthStatus.locked;
    notifyListeners();
  }

  // ------------------------------------------------------------ perfil
  Future<void> update(Account a) async {
    await _repo.save(a);
    account = a;
    notifyListeners();
  }

  Future<bool> changePassword(String current, String next) async {
    final a = account;
    if (a == null || AccountRepository.hash(current, a.salt) != a.passHash) return false;
    final salt = AccountRepository.newSalt();
    await update(a.copyWith(salt: salt, passHash: AccountRepository.hash(next, salt)));
    return true;
  }

  Future<void> deleteEverything() async {
    await _repo.wipe();
    account = null;
    passed.clear();
    lockedOut = false;
    status = AuthStatus.noAccount;
    notifyListeners();
  }
}
