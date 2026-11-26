import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/constants/app_constants.dart';

/// Notificación de resumen al guardar un entrenamiento.
/// La notificación fija del servicio de ubicación la crea LocationService.
/// Todo va en try/catch: si falla, la app sigue funcionando.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _ready = false;

  static const String _summaryChannelId = 'fitpulse_summary';
  static const String _summaryChannelName = 'Resumen de entrenamientos';

  Future<void> init() async {
    if (_ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(const InitializationSettings(android: android));
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> showWorkoutSaved({
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          _summaryChannelId,
          _summaryChannelName,
          channelDescription: 'Aviso cuando se guarda un entrenamiento',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      );
      await _plugin.show(AppConstants.notificationId + 1, title, body, details);
    } catch (_) {
      // Sin permiso o sin soporte: se ignora.
    }
  }
}
