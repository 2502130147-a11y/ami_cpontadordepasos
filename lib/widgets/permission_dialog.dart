import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/permission_service.dart';

class PermissionInfo {
  const PermissionInfo({
    required this.icon,
    required this.title,
    required this.rationale,
    required this.settingsMessage,
  });

  final IconData icon;
  final String title;

  /// Se muestra ANTES de pedir el permiso al sistema.
  final String rationale;

  /// Se muestra cuando el permiso quedó bloqueado (denegado permanentemente).
  final String settingsMessage;
}

/// Diálogos informativos y flujo completo de permisos.
class PermissionDialogs {
  PermissionDialogs._();

  static const PermissionInfo location = PermissionInfo(
    icon: Icons.location_on_rounded,
    title: 'Permiso de ubicación',
    rationale:
    'FitPulse usa tu ubicación (GPS) para dibujar tu ruta en el mapa y '
        'calcular tu distancia y velocidad. Si envías la app a segundo plano, '
        'el entrenamiento sigue registrándose y verás una notificación fija. '
        'Tus datos se quedan en tu teléfono.',
    settingsMessage:
    'El permiso de ubicación está bloqueado. Ábrelo en Ajustes > Permisos > '
        'Ubicación y elige "Permitir solo mientras se usa la app".',
  );

  static const PermissionInfo activity = PermissionInfo(
    icon: Icons.directions_walk_rounded,
    title: 'Permiso de actividad física',
    rationale:
    'FitPulse necesita este permiso para leer el podómetro del teléfono y '
        'contar tus pasos durante el entrenamiento. Si no lo das, los pasos '
        'se estimarán con el acelerómetro.',
    settingsMessage:
    'El permiso de actividad física está bloqueado. Ábrelo en Ajustes > '
        'Permisos > Actividad física para contar pasos con el podómetro.',
  );

  static const PermissionInfo notifications = PermissionInfo(
    icon: Icons.notifications_active_rounded,
    title: 'Permiso de notificaciones',
    rationale:
    'Las notificaciones muestran que tu entrenamiento sigue activo en '
        'segundo plano y te avisan cuando se guarda. Es opcional: la app '
        'funciona igual sin ellas.',
    settingsMessage:
    'Las notificaciones están bloqueadas. Puedes activarlas en Ajustes > '
        'Notificaciones si quieres verlas.',
  );

  static PermissionInfo _infoFor(AppPermission p) {
    switch (p) {
      case AppPermission.location:
        return location;
      case AppPermission.activity:
        return activity;
      case AppPermission.notifications:
        return notifications;
    }
  }

  /// Flujo completo: ya concedido -> listo; si no, diálogo informativo ->
  /// permiso del sistema -> si queda bloqueado, diálogo para abrir Ajustes.
  ///
  /// [showSettingsIfBlocked] en false sirve para permisos opcionales
  /// (notificaciones): no se insiste.
  static Future<PermState> ensure(
      BuildContext context,
      PermissionService service,
      AppPermission permission, {
        bool showSettingsIfBlocked = true,
      }) async {
    final info = _infoFor(permission);
    var state = await service.status(permission);
    if (state == PermState.granted) return state;
    if (!context.mounted) return state;

    if (state == PermState.permanentlyDenied) {
      if (showSettingsIfBlocked) {
        await _settingsDialog(context, service, info);
      }
      return service.status(permission);
    }

    final proceed = await _confirm(
      context,
      icon: info.icon,
      title: info.title,
      message: info.rationale,
    );
    if (!proceed) return state;

    state = await service.request(permission);
    if (state == PermState.permanentlyDenied &&
        showSettingsIfBlocked &&
        context.mounted) {
      await _settingsDialog(context, service, info);
      return service.status(permission);
    }
    return state;
  }

  /// Diálogo informativo previo al uso de la huella (permiso de biometría).
  /// Devuelve true si el usuario quiere continuar.
  static Future<bool> confirmBiometric(BuildContext context) {
    return _confirm(
      context,
      icon: Icons.fingerprint_rounded,
      title: 'Acceso con huella',
      message:
      'Vamos a pedirte tu huella para comprobar que eres tú. FitPulse no '
          'guarda tu huella: la verificación la hace Android y la app solo '
          'recibe si coincidió o no.',
      confirmLabel: 'Continuar',
    );
  }

  static Future<bool> _confirm(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String message,
        String confirmLabel = 'Continuar',
        String cancelLabel = 'Ahora no',
      }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _InfoDialog(
        icon: icon,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      ),
    );
    return result ?? false;
  }

  static Future<void> _settingsDialog(
      BuildContext context,
      PermissionService service,
      PermissionInfo info,
      ) async {
    final open = await _confirm(
      context,
      icon: Icons.settings_rounded,
      title: 'Permiso bloqueado',
      message: info.settingsMessage,
      confirmLabel: 'Abrir ajustes',
      cancelLabel: 'Cancelar',
    );
    if (open) await service.openSettings();
  }
}

class _InfoDialog extends StatelessWidget {
  const _InfoDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      icon: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.16),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 30, color: AppColors.primary),
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}