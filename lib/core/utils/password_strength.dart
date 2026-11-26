import 'dart:math' as math;

import '../constants/app_constants.dart';

/// Niveles del indicador de seguridad.
enum PasswordLevel {
  veryWeak('Muy débil'),
  weak('Débil'),
  medium('Media'),
  strong('Fuerte'),
  veryStrong('Muy fuerte');

  const PasswordLevel(this.label);
  final String label;
}

/// Un requisito de la lista en vivo (se marca cuando se cumple).
class PasswordRule {
  const PasswordRule(this.label, this.passed);
  final String label;
  final bool passed;
}

class PasswordAnalysis {
  const PasswordAnalysis({
    required this.rules,
    required this.score,
    required this.level,
    required this.isEmpty,
  });

  final List<PasswordRule> rules;

  /// Puntaje interno de 0 a 6.
  final int score;
  final PasswordLevel level;
  final bool isEmpty;

  /// Válida = cumple TODOS los requisitos obligatorios.
  bool get isValid => !isEmpty && rules.every((r) => r.passed);

  /// Avance de la barra, de 0.0 a 1.0.
  double get progress =>
      isEmpty ? 0 : (level.index + 1) / PasswordLevel.values.length;

  /// Mensaje del primer requisito que falta (o null si está completa).
  String? get firstError {
    for (final r in rules) {
      if (!r.passed) return 'Falta cumplir: ${r.label}';
    }
    return null;
  }
}

class PasswordStrength {
  PasswordStrength._();

  static final RegExp _upper = RegExp(r'[A-Z]');
  static final RegExp _lower = RegExp(r'[a-z]');
  static final RegExp _digit = RegExp(r'[0-9]');
  static final RegExp _space = RegExp(r'\s');
  static final RegExp _repeated = RegExp(r'(.)\1\1');

  static const List<String> _common = [
    'password',
    'contrasena',
    'contraseña',
    'qwerty',
    '123456',
    'abc123',
    'admin',
  ];

  /// Símbolo = carácter ASCII imprimible que no es letra ni número.
  static bool _hasSymbol(String s) {
    for (final c in s.runes) {
      final isDigit = c >= 48 && c <= 57;
      final isUpper = c >= 65 && c <= 90;
      final isLower = c >= 97 && c <= 122;
      if (c >= 33 && c <= 126 && !isDigit && !isUpper && !isLower) {
        return true;
      }
    }
    return false;
  }

  static PasswordAnalysis evaluate(String password) {
    final isEmpty = password.isEmpty;
    final hasLength = password.length >= AppConstants.passwordMinLength;
    final hasUpper = _upper.hasMatch(password);
    final hasLower = _lower.hasMatch(password);
    final hasDigit = _digit.hasMatch(password);
    final hasSymbol = _hasSymbol(password);
    final noSpaces = !isEmpty && !_space.hasMatch(password);

    final rules = <PasswordRule>[
      PasswordRule(
        'Mínimo ${AppConstants.passwordMinLength} caracteres',
        hasLength,
      ),
      PasswordRule('Una letra mayúscula (A-Z)', hasUpper),
      PasswordRule('Una letra minúscula (a-z)', hasLower),
      PasswordRule('Un número (0-9)', hasDigit),
      PasswordRule('Un símbolo (por ejemplo ! @ # \$ %)', hasSymbol),
      PasswordRule('Sin espacios', noSpaces),
    ];

    var score = 0;
    if (hasLength) score++;
    if (hasUpper) score++;
    if (hasLower) score++;
    if (hasDigit) score++;
    if (hasSymbol) score++;
    if (password.length >= 12) score++;

    // Penalizaciones por patrones débiles.
    final lower = password.toLowerCase();
    if (_common.any(lower.contains)) score -= 2;
    if (_repeated.hasMatch(password)) score -= 1;
    score = math.max(0, math.min(6, score));

    final PasswordLevel level;
    if (score <= 1) {
      level = PasswordLevel.veryWeak;
    } else if (score == 2) {
      level = PasswordLevel.weak;
    } else if (score <= 4) {
      level = PasswordLevel.medium;
    } else if (score == 5) {
      level = PasswordLevel.strong;
    } else {
      level = PasswordLevel.veryStrong;
    }

    return PasswordAnalysis(
      rules: rules,
      score: score,
      level: level,
      isEmpty: isEmpty,
    );
  }
}