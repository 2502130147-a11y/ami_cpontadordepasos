import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

enum BiometricAvailability { available, notEnrolled, notSupported }

enum BiometricOutcome {
  success,
  failed,
  notSupported,
  notEnrolled,
  lockedOut,
  error,
}

/// Resultado listo para mostrarse en una alerta de éxito o de fallo.
class BiometricResult {
  const BiometricResult(this.outcome, this.message);

  final BiometricOutcome outcome;
  final String message;

  bool get isSuccess => outcome == BiometricOutcome.success;
}

/// Envoltorio de `local_auth`. Nunca lanza excepciones (RNF-04).
class BiometricService {
  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<BiometricAvailability> availability() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return BiometricAvailability.notSupported;
      final enrolled = await _auth.getAvailableBiometrics();
      if (enrolled.isEmpty) return BiometricAvailability.notEnrolled;
      return BiometricAvailability.available;
    } catch (_) {
      return BiometricAvailability.notSupported;
    }
  }

  Future<BiometricResult> authenticate({
    String reason = 'Verifica tu identidad con tu huella para continuar',
  }) async {
    final availability = await this.availability();
    if (availability == BiometricAvailability.notSupported) {
      return const BiometricResult(
        BiometricOutcome.notSupported,
        'Este dispositivo no tiene lector de huella disponible.',
      );
    }
    if (availability == BiometricAvailability.notEnrolled) {
      return const BiometricResult(
        BiometricOutcome.notEnrolled,
        'No hay huellas registradas. Agrega una en Ajustes del teléfono.',
      );
    }

    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Verificación con huella',
            biometricHint: 'Coloca tu dedo en el sensor',
            biometricNotRecognized: 'Huella no reconocida, intenta de nuevo',
            biometricSuccess: 'Huella verificada',
            cancelButton: 'Cancelar',
          ),
        ],
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: false,
        ),
      );
      if (ok) {
        return const BiometricResult(
          BiometricOutcome.success,
          'Huella verificada correctamente.',
        );
      }
      return const BiometricResult(
        BiometricOutcome.failed,
        'No se pudo verificar la huella o se canceló la verificación.',
      );
    } on PlatformException catch (e) {
      return _fromPlatformException(e);
    } catch (_) {
      return const BiometricResult(
        BiometricOutcome.error,
        'Ocurrió un error al usar la huella.',
      );
    }
  }

  BiometricResult _fromPlatformException(PlatformException e) {
    switch (e.code) {
      case 'NotEnrolled':
      case 'PasscodeNotSet':
        return const BiometricResult(
          BiometricOutcome.notEnrolled,
          'No hay huellas registradas en este teléfono.',
        );
      case 'NotAvailable':
        return const BiometricResult(
          BiometricOutcome.notSupported,
          'La huella no está disponible en este dispositivo.',
        );
      case 'LockedOut':
        return const BiometricResult(
          BiometricOutcome.lockedOut,
          'Demasiados intentos fallidos. Espera unos segundos e intenta de nuevo.',
        );
      case 'PermanentlyLockedOut':
        return const BiometricResult(
          BiometricOutcome.lockedOut,
          'La huella quedó bloqueada. Desbloquea el teléfono con tu PIN y vuelve a intentar.',
        );
      case 'no_fragment_activity':
        return const BiometricResult(
          BiometricOutcome.error,
          'Configuración de Android incompleta: MainActivity debe usar FlutterFragmentActivity.',
        );
      case 'auth_in_progress':
        return const BiometricResult(
          BiometricOutcome.error,
          'Ya hay una verificación en curso.',
        );
      default:
        return BiometricResult(
          BiometricOutcome.error,
          'No se pudo usar la huella (${e.code}).',
        );
    }
  }
}