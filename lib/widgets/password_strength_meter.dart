import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/password_strength.dart';

/// Barra de color + nivel + lista de requisitos que se marcan en vivo.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final analysis = PasswordStrength.evaluate(password);
    final color = analysis.isEmpty
        ? AppColors.textSecondary
        : AppColors.passwordLevels[analysis.level.index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: analysis.progress,
            minHeight: 8,
            color: color,
            backgroundColor: AppColors.surfaceAlt,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          analysis.isEmpty
              ? 'Escribe una contraseña'
              : 'Seguridad: ${analysis.level.label}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        for (final rule in analysis.rules)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    rule.passed
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color:
                    rule.passed ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rule.label,
                    style: TextStyle(
                      fontSize: 13,
                      color: rule.passed
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}