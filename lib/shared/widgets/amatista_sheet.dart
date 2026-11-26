import 'package:flutter/material.dart';

import '../../app/theme/palette.dart';
import 'gradient_button.dart';
import 'soft_card.dart';

/// Hoja inferior con ícono, título, explicación y dos acciones.
/// Devuelve true (acción principal), false (secundaria) o null (cerrada).
Future<bool?> showAmatistaSheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  required Widget body,
  String primary = 'Continuar',
  String? secondary = 'Ahora no',
  bool dismissible = true,
  Gradient badge = Palette.lilacButton,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: IconBadge(icon, size: 68, gradient: badge)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Palette.ink),
            ),
            const SizedBox(height: 12),
            DefaultTextStyle.merge(
              style: const TextStyle(color: Palette.inkMuted, height: 1.4, fontSize: 14),
              child: body,
            ),
            const SizedBox(height: 22),
            GradientButton(label: primary, onPressed: () => Navigator.pop(ctx, true)),
            if (secondary != null) ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(secondary),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Renglón "ícono + título + explicación" para las hojas de permisos.
class ReasonRow extends StatelessWidget {
  const ReasonRow(this.icon, this.title, this.text, {super.key});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Palette.lilacSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: Palette.purple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.ink, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(color: Palette.inkMuted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum FlashKind { success, error, info }

/// Aviso flotante de éxito / error / información.
void showFlash(BuildContext context, String message, {FlashKind kind = FlashKind.info}) =>
    showFlashWith(ScaffoldMessenger.of(context), message, kind: kind);

/// Igual que [showFlash], pero con el ScaffoldMessenger ya obtenido
/// (sirve cuando la pantalla que lo pidió ya no existe).
void showFlashWith(ScaffoldMessengerState messenger, String message, {FlashKind kind = FlashKind.info}) {
  final (IconData icon, Color color) = switch (kind) {
    FlashKind.success => (Icons.verified_rounded, const Color(0xFF7EE2B8)),
    FlashKind.error => (Icons.error_rounded, const Color(0xFFFF9AB0)),
    FlashKind.info => (Icons.info_rounded, Palette.lilac),
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Diálogo de confirmación con estilo de la app.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Sí, continuar',
  bool destructive = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(
            foregroundColor: destructive ? Palette.danger : Palette.purple,
          ),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return r ?? false;
}
