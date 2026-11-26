import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

/// Los dos métodos biométricos que usa la app.
enum BioKind {
  fingerprint,
  face;

  String get label => this == BioKind.fingerprint ? 'Huella' : 'Rostro';
}

/// Qué ofrece el teléfono.
class BioSupport {
  const BioSupport({required this.hardware, required this.enrolled, required this.types});

  static const none = BioSupport(hardware: false, enrolled: false, types: []);

  final bool hardware; // el equipo tiene sensor biométrico
  final bool enrolled; // hay al menos una huella / rostro registrado
  final List<BiometricType> types;

  bool get ready => hardware && enrolled;
}

/// Resultado de una verificación, con mensaje listo para mostrar.
class BioOutcome {
  const BioOutcome(this.ok, this.message, {this.lockedOut = false, this.unavailable = false});

  final bool ok;
  final String message;
  final bool lockedOut;
  final bool unavailable;
}

/// Envoltorio de `local_auth` para huella y rostro.
///
/// Android no deja a las apps elegir el sensor: el sistema muestra su diálogo
/// biométrico y acepta lo que el usuario tenga registrado. Por eso cada paso
/// usa un título e instrucciones propias ("Verificación de huella" /
/// "Verificación facial") para guiar al usuario hacia el método correcto.
class BiometricGateway {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<BioSupport> probe() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final types = supported ? await _auth.getAvailableBiometrics() : <BiometricType>[];
      debugPrint('AMATISTA_BIO probe supported=$supported canCheck=$canCheck types=$types');
      return BioSupport(hardware: supported && canCheck, enrolled: types.isNotEmpty, types: types);
    } catch (_) {
      return BioSupport.none;
    }
  }

  Future<BioOutcome> verify(BioKind kind, {required String purpose}) async {
    final isFace = kind == BioKind.face;
    try {
      final ok = await _auth.authenticate(
        localizedReason: isFace
            ? 'Mira a la cámara frontal para $purpose con tu rostro'
            : 'Apoya tu dedo en el lector para $purpose con tu huella',
        authMessages: [
          AndroidAuthMessages(
            signInTitle: isFace ? 'Verificación facial' : 'Verificación de huella',
            biometricHint: isFace ? 'Mantén el rostro frente a la pantalla' : 'Toca el sensor de huella',
            biometricNotRecognized: isFace ? 'Rostro no reconocido' : 'Huella no reconocida',
            biometricSuccess: isFace ? 'Rostro verificado' : 'Huella verificada',
            cancelButton: 'Cancelar',
          ),
        ],
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      debugPrint('AMATISTA_BIO authenticate(${kind.name}) -> $ok');
      if (ok) {
        return BioOutcome(true, isFace ? 'Rostro verificado correctamente' : 'Huella verificada correctamente');
      }
      return BioOutcome(
        false,
        isFace ? 'No se pudo verificar tu rostro. Intenta de nuevo.' : 'No se pudo verificar tu huella. Intenta de nuevo.',
      );
    } on PlatformException catch (e) {
      // Diagnóstico: el código aparece en la consola Run de Android Studio.
      debugPrint('AMATISTA_BIO PlatformException code=${e.code} message=${e.message} details=${e.details}');
      switch (e.code) {
        case auth_error.lockedOut:
          return const BioOutcome(false, 'Demasiados intentos. Espera 30 segundos.', lockedOut: true);
        case auth_error.permanentlyLockedOut:
          return const BioOutcome(
            false,
            'Biometría bloqueada. Desbloquea el teléfono con tu PIN o usa tu contraseña.',
            lockedOut: true,
          );
        case auth_error.notEnrolled:
          return BioOutcome(
            false,
            isFace
                ? 'No hay un rostro registrado en los ajustes del teléfono.'
                : 'No hay una huella registrada en los ajustes del teléfono.',
            unavailable: true,
          );
        case auth_error.notAvailable:
        case auth_error.passcodeNotSet:
          return const BioOutcome(
            false,
            'La biometría no está disponible en este dispositivo.',
            unavailable: true,
          );
        default:
          return BioOutcome(false, 'Error de huella [${e.code}]: ${e.message ?? 'sin detalle'}');
      }
    } catch (e) {
      debugPrint('AMATISTA_BIO error=$e');
      return BioOutcome(false, 'Error de verificación biométrica: $e');
    }
  }
}
