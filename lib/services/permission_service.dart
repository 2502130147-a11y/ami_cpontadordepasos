import 'package:permission_handler/permission_handler.dart';

/// Permisos de ejecución que usa la app.
/// La huella no necesita permiso de ejecución en Android; se valida con
/// BiometricService (disponibilidad y huellas registradas).
enum AppPermission { location, activity, notifications }

enum PermState { granted, denied, permanentlyDenied }

/// Envoltorio de `permission_handler`.
/// Quien llama debe mostrar un diálogo informativo ANTES de `request`.
class PermissionService {
  Permission _native(AppPermission p) {
    switch (p) {
      case AppPermission.location:
        return Permission.locationWhenInUse;
      case AppPermission.activity:
        return Permission.activityRecognition;
      case AppPermission.notifications:
        return Permission.notification;
    }
  }

  PermState _map(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return PermState.granted;
    if (s.isPermanentlyDenied) return PermState.permanentlyDenied;
    return PermState.denied;
  }

  Future<PermState> status(AppPermission p) async {
    try {
      return _map(await _native(p).status);
    } catch (_) {
      return PermState.denied;
    }
  }

  Future<PermState> request(AppPermission p) async {
    try {
      return _map(await _native(p).request());
    } catch (_) {
      return PermState.denied;
    }
  }

  Future<bool> isGranted(AppPermission p) async =>
      await status(p) == PermState.granted;

  /// Abre los ajustes de la app (para "denegado permanentemente").
  Future<bool> openSettings() async {
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }
}