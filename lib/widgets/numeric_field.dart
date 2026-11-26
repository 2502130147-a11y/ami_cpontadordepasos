import 'package:flutter/material.dart';

import '../core/utils/validators.dart';

/// Campo que acepta SOLO números (bloquea letras y símbolos al escribir).
/// El rango lo valida [validator] (por ejemplo `Validators.weight`).
class NumericField extends StatelessWidget {
  const NumericField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    required this.maxLength,
    this.icon,
    this.unit,
    this.hint,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final int maxLength;
  final IconData? icon;
  final String? unit;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: false,
        signed: false,
      ),
      textInputAction: textInputAction,
      inputFormatters: InputFormatters.digits(maxLength),
      validator: validator,
      onChanged: onChanged,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        suffixText: unit,
      ),
    );
  }
}