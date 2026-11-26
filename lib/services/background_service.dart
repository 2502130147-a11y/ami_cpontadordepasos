import 'package:flutter/widgets.dart';

/// Avisa cuando la app pasa a segundo plano y cuando vuelve.
///
/// Solo `paused` y `resumed` cuentan. `inactive` (diálogo de permisos,
/// huella, barra de notificaciones) NO es segundo plano.
class BackgroundService with WidgetsBindingObserver {
  void Function()? _onBackground;
  void Function()? _onForeground;
  bool _attached = false;
  bool _inBackground = false;

  bool get isInBackground => _inBackground;

  void attach({
    required void Function() onBackground,
    required void Function() onForeground,
  }) {
    _onBackground = onBackground;
    _onForeground = onForeground;
    if (!_attached) {
      WidgetsBinding.instance.addObserver(this);
      _attached = true;
    }
  }

  /// Quita el observador (se llama en dispose para no dejar fugas).
  void detach() {
    if (_attached) {
      WidgetsBinding.instance.removeObserver(this);
      _attached = false;
    }
    _onBackground = null;
    _onForeground = null;
    _inBackground = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        if (!_inBackground) {
          _inBackground = true;
          _onBackground?.call();
        }
      case AppLifecycleState.resumed:
        if (_inBackground) {
          _inBackground = false;
          _onForeground?.call();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }
}