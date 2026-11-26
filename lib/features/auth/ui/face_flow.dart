import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/permissions/permission_gate.dart';
import '../../../shared/widgets/amatista_sheet.dart';
import '../logic/auth_store.dart';
import 'face_scan_page.dart';

/// Registra el rostro con la cámara y guarda la plantilla en el perfil.
Future<bool> enrollFace(BuildContext context) async {
  final store = context.read<AuthStore>();
  final nav = Navigator.of(context);
  final allowed = await PermissionGate.forCamera(context);
  if (!allowed) {
    if (context.mounted) {
      showFlash(context, 'Sin permiso de cámara no se puede registrar el rostro.', kind: FlashKind.error);
    }
    return false;
  }
  final r = await nav.push<FaceScanResult>(
    MaterialPageRoute(builder: (_) => const FaceScanPage(mode: FaceScanMode.enroll)),
  );
  if (!context.mounted) return false;
  if (r != null && r.ok && r.template != null) {
    await store.saveFaceTemplate(r.template!);
    if (context.mounted) showFlash(context, r.message, kind: FlashKind.success);
    return true;
  }
  showFlash(context, r?.message ?? 'Registro facial cancelado', kind: FlashKind.error);
  return false;
}

/// Paso facial del desbloqueo. Devuelve true si se reconoció el rostro.
Future<bool> verifyFaceStep(BuildContext context) async {
  final store = context.read<AuthStore>();
  final nav = Navigator.of(context);
  final template = store.faceTemplate;
  if (template == null) {
    showFlash(context, 'Registra tu rostro desde el perfil.', kind: FlashKind.error);
    return false;
  }
  final allowed = await PermissionGate.forCamera(context);
  if (!allowed) {
    store.faceStepResult(false);
    if (context.mounted) {
      showFlash(context, 'Se necesita la cámara para verificar tu rostro.', kind: FlashKind.error);
    }
    return false;
  }
  final r = await nav.push<FaceScanResult>(
    MaterialPageRoute(builder: (_) => FaceScanPage(mode: FaceScanMode.verify, template: template)),
  );
  final ok = r?.ok ?? false;
  // El aviso se muestra antes de actualizar el estado, porque si este era el
  // último paso la pantalla de desbloqueo se reemplaza por el inicio.
  final pending = store.requiredKinds.where((k) => !store.passed.contains(k)).length;
  if (context.mounted) {
    showFlash(
      context,
      ok
          ? (pending <= 1 ? '¡Acceso concedido! Bienvenido(a), ${store.account?.firstName ?? ''}' : r!.message)
          : (r?.message ?? 'Verificación facial cancelada'),
      kind: ok ? FlashKind.success : FlashKind.error,
    );
  }
  store.faceStepResult(ok);
  return ok;
}
