import 'package:flutter/services.dart';

import '../constants/app_constants.dart';
import 'password_strength.dart';

/// Filtros de teclado: bloquean caracteres inválidos MIENTRAS se escribe.
class InputFormatters {
  InputFormatters._();

  /// Solo letras (con acentos y ñ) y espacios.
  static final List<TextInputFormatter> name = [
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ ]')),
    LengthLimitingTextInputFormatter(AppConstants.nameMaxLength),
  ];

  /// Solo letras y números, máximo 20.
  static final List<TextInputFormatter> username = [
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
    LengthLimitingTextInputFormatter(AppConstants.usernameMaxLength),
  ];

  /// Cualquier carácter menos espacios.
  static final List<TextInputFormatter> password = [
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
    LengthLimitingTextInputFormatter(AppConstants.passwordMaxLength),
  ];

  /// Solo dígitos, con longitud máxima.
  static List<TextInputFormatter> digits(int maxLength) => [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(maxLength),
  ];
}

/// Validadores para `TextFormField.validator` (null = válido).
class Validators {
  Validators._();

  static final RegExp _nameFull =
  RegExp(r'^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+(?: +[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+)*$');
  static final RegExp _username = RegExp(r'^[A-Za-z0-9]+$');

  static String? name(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingresa tu nombre';
    if (v.length < AppConstants.nameMinLength) {
      return 'Mínimo ${AppConstants.nameMinLength} letras';
    }
    if (!_nameFull.hasMatch(v)) return 'Solo letras y espacios';
    return null;
  }

  static String? username(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingresa un usuario';
    if (v.length < AppConstants.usernameMinLength ||
        v.length > AppConstants.usernameMaxLength) {
      return 'Entre ${AppConstants.usernameMinLength} y '
          '${AppConstants.usernameMaxLength} caracteres';
    }
    if (!_username.hasMatch(v)) return 'Solo letras y números';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Ingresa una contraseña';
    return PasswordStrength.evaluate(v).firstError;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Confirma tu contraseña';
    if (value != original) return 'Las contraseñas no coinciden';
    return null;
  }

  /// Campo numérico entero con rango. [label] va en el mensaje de error.
  static String? intInRange(
      String? value, {
        required int min,
        required int max,
        required String label,
        String unit = '',
      }) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingresa $label';
    final n = int.tryParse(v);
    if (n == null) return 'Solo números';
    if (n < min || n > max) {
      final u = unit.isEmpty ? '' : ' $unit';
      return 'Debe estar entre $min y $max$u';
    }
    return null;
  }

  static String? weight(String? v) => intInRange(v,
      min: AppConstants.minWeightKg,
      max: AppConstants.maxWeightKg,
      label: 'tu peso',
      unit: 'kg');

  static String? height(String? v) => intInRange(v,
      min: AppConstants.minHeightCm,
      max: AppConstants.maxHeightCm,
      label: 'tu estatura',
      unit: 'cm');

  static String? age(String? v) => intInRange(v,
      min: AppConstants.minAge,
      max: AppConstants.maxAge,
      label: 'tu edad',
      unit: 'años');

  static String? dailyGoal(String? v) => intInRange(v,
      min: AppConstants.minDailyGoal,
      max: AppConstants.maxDailyGoal,
      label: 'tu meta diaria',
      unit: 'pasos');
}