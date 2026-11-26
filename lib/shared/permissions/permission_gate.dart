import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme/palette.dart';
import '../widgets/amatista_sheet.dart';

typedef TrainingGrants = ({bool location, bool activity});

/// Permisos en tiempo de ejecución, SIEMPRE precedidos por una explicación.
abstract final class PermissionGate {
  /// Biometría: en Android USE_BIOMETRIC se concede al instalar, pero el
  /// usuario debe saber para qué se usará su huella y su rostro antes de
  /// abrir el diálogo del sistema.
  static Future<bool> explainBiometrics(BuildContext context) async {
    final ok = await showAmatistaSheet(
      context,
      icon: Icons.admin_panel_settings_rounded,
      title: 'Permiso de biometría',
      primary: 'Permitir y continuar',
      body: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Amatista protege tu perfil con dos verificaciones:'),
          SizedBox(height: 14),
          ReasonRow(Icons.fingerprint_rounded, 'Huella dactilar',
              'Se valida con el lector de huellas registrado en tu teléfono.'),
          ReasonRow(Icons.face_retouching_natural_rounded, 'Reconocimiento facial',
              'Se valida con la cámara frontal: la app reconoce la forma de tu rostro y te pide sonreír.'),
          ReasonRow(Icons.lock_rounded, 'Privacidad',
              'Nada sale del teléfono: de la huella solo se recibe "aprobado" o "rechazado" y del rostro solo se guarda su forma, nunca la foto.'),
        ],
      ),
    );
    return ok == true;
  }

  /// Cámara frontal para el reconocimiento facial.
  static Future<bool> forCamera(BuildContext context) async {
    var st = await Permission.camera.status;
    if (st.isGranted) return true;
    if (!context.mounted) return false;
    final go = await showAmatistaSheet(
      context,
      icon: Icons.photo_camera_front_rounded,
      title: 'Permiso de cámara',
      primary: 'Permitir cámara',
      body: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReasonRow(Icons.face_retouching_natural_rounded, 'Reconocimiento facial',
              'La cámara frontal se usa solo durante la verificación para reconocer tu rostro.'),
          ReasonRow(Icons.lock_rounded, 'Sin fotos guardadas',
              'Las imágenes se analizan en el teléfono y se borran al instante. Solo se guarda la forma de tu rostro.'),
        ],
      ),
    );
    if (go != true) return false;
    st = await Permission.camera.request();
    if (st.isPermanentlyDenied && context.mounted) {
      final open = await showAmatistaSheet(
        context,
        icon: Icons.block_rounded,
        title: 'Cámara bloqueada',
        primary: 'Abrir ajustes',
        secondary: 'Cancelar',
        badge: const LinearGradient(colors: [Palette.danger, Palette.violet]),
        body: const Text(
          'Activa el permiso de cámara en los ajustes de la app para usar el reconocimiento facial.',
          textAlign: TextAlign.center,
        ),
      );
      if (open == true) await openAppSettings();
    }
    return st.isGranted;
  }

  /// Ubicación + actividad física (+ notificaciones para el servicio en
  /// primer plano). Devuelve qué permisos quedaron concedidos.
  static Future<TrainingGrants> forTraining(BuildContext context) async {
    var loc = await Permission.locationWhenInUse.status;
    var act = await Permission.activityRecognition.status;

    if (!(loc.isGranted && act.isGranted)) {
      if (!context.mounted) return (location: loc.isGranted, activity: act.isGranted);
      final go = await showAmatistaSheet(
        context,
        icon: Icons.sensors_rounded,
        title: 'Antes de entrenar',
        primary: 'Conceder permisos',
        body: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Para medir tu sesión en tiempo real necesitamos:'),
            SizedBox(height: 14),
            ReasonRow(Icons.location_on_rounded, 'Ubicación',
                'Obtener tus coordenadas, dibujar la ruta en el mapa y calcular distancia y velocidad.'),
            ReasonRow(Icons.directions_walk_rounded, 'Actividad física',
                'Leer el podómetro del teléfono para contar tus pasos.'),
            ReasonRow(Icons.notifications_active_rounded, 'Notificaciones',
                'Mostrar un aviso mientras la ruta se sigue registrando con la pantalla apagada.'),
          ],
        ),
      );
      if (go != true) return (location: loc.isGranted, activity: act.isGranted);

      final res = await [Permission.locationWhenInUse, Permission.activityRecognition].request();
      loc = res[Permission.locationWhenInUse] ?? loc;
      act = res[Permission.activityRecognition] ?? act;

      if ((loc.isPermanentlyDenied || act.isPermanentlyDenied) && context.mounted) {
        final open = await showAmatistaSheet(
          context,
          icon: Icons.block_rounded,
          title: 'Permiso bloqueado',
          primary: 'Abrir ajustes',
          secondary: 'Seguir sin él',
          badge: const LinearGradient(colors: [Palette.danger, Palette.violet]),
          body: const Text(
            'Negaste un permiso de forma permanente. Actívalo en los ajustes de la app '
            'para usar el GPS o el podómetro. Mientras tanto la app usará lo que tenga disponible.',
            textAlign: TextAlign.center,
          ),
        );
        if (open == true) await openAppSettings();
      }
    }

    // Notificaciones (Android 13+). Opcional: si se niega, todo sigue funcionando.
    final n = await Permission.notification.status;
    if (n.isDenied) await Permission.notification.request();

    // GPS apagado
    if (loc.isGranted && context.mounted) {
      final on = await Geolocator.isLocationServiceEnabled();
      if (!on && context.mounted) {
        final open = await showAmatistaSheet(
          context,
          icon: Icons.location_off_rounded,
          title: 'Tu GPS está apagado',
          primary: 'Activar GPS',
          secondary: 'Continuar sin mapa',
          body: const Text(
            'Enciende la ubicación para trazar tu recorrido en el mapa.',
            textAlign: TextAlign.center,
          ),
        );
        if (open == true) await Geolocator.openLocationSettings();
      }
    }

    return (location: loc.isGranted, activity: act.isGranted);
  }
}
