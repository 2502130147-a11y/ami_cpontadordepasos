import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/palette.dart';
import '../../../shared/permissions/permission_gate.dart';
import '../../../shared/widgets/amatista_sheet.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/soft_card.dart';
import '../data/biometric_gateway.dart';
import '../logic/auth_store.dart';
import 'face_flow.dart';

/// Después del registro: vincular huella Y rostro al perfil.
class BioEnrollPage extends StatefulWidget {
  const BioEnrollPage({super.key});

  @override
  State<BioEnrollPage> createState() => _BioEnrollPageState();
}

class _BioEnrollPageState extends State<BioEnrollPage> {
  bool _explained = false;

  Future<void> _link(BioKind kind) async {
    final store = context.read<AuthStore>();
    if (!_explained) {
      final ok = await PermissionGate.explainBiometrics(context);
      if (!ok || !mounted) return;
      _explained = true;
    }
    if (kind == BioKind.face) {
      await enrollFace(context);
      return;
    }
    await store.refreshSupport();
    if (!mounted) return;
    if (!store.support.ready) {
      showFlash(
        context,
        'Registra una huella en los ajustes de tu teléfono y vuelve a intentarlo.',
        kind: FlashKind.error,
      );
      return;
    }
    final r = await store.link(kind);
    if (!mounted) return;
    showFlash(context, r.message, kind: r.ok ? FlashKind.success : FlashKind.error);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AuthStore>();
    final acc = store.account;
    final finger = acc?.fingerLinked ?? false;
    final face = acc?.faceLinked ?? false;
    final noBio = !store.support.ready;
    final done = finger && face;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
          children: [
            const Text(
              'Paso 2 de 2',
              style: TextStyle(color: Palette.violet, fontWeight: FontWeight.w800, letterSpacing: 1),
            ),
            const SizedBox(height: 6),
            Text(
              'Protege tu perfil, ${acc?.firstName ?? ''}',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15),
            ),
            const SizedBox(height: 8),
            const Text(
              'Vincula los dos métodos. Para entrar a Amatista se pedirán uno después del otro: '
              'primero tu huella y después tu rostro.',
              style: TextStyle(color: Palette.inkMuted, height: 1.4),
            ),
            const SizedBox(height: 26),
            _MethodTile(
              step: 1,
              kind: BioKind.fingerprint,
              icon: Icons.fingerprint_rounded,
              title: 'Huella dactilar',
              hint: 'Usa el dedo que registraste en el teléfono.',
              linked: finger,
              busy: store.busy,
              onTap: () => _link(BioKind.fingerprint),
            ),
            const SizedBox(height: 14),
            _MethodTile(
              step: 2,
              kind: BioKind.face,
              icon: Icons.face_retouching_natural_rounded,
              title: 'Reconocimiento facial',
              hint: 'Mira de frente a la cámara con buena luz.',
              linked: face,
              busy: store.busy,
              onTap: () => _link(BioKind.face),
            ),
            if (noBio) ...[
              const SizedBox(height: 18),
              SoftCard(
                color: Palette.lilacSoft,
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_rounded, color: Palette.purple),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No detectamos una huella registrada en este teléfono. '
                        'Regístrala en Ajustes > Seguridad y vuelve a intentarlo. '
                        'El rostro sí se puede registrar: usa la cámara frontal.',
                        style: TextStyle(color: Palette.plum, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 30),
            GradientButton(
              label: done ? 'Entrar a Amatista' : 'Vincula ambos métodos',
              icon: done ? Icons.lock_open_rounded : Icons.lock_rounded,
              onPressed: done ? store.finishEnrollment : null,
            ),
            if (!done) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: (finger || face || noBio)
                    ? () async {
                        final ok = await confirmAction(
                          context,
                          title: 'Continuar sin ambos métodos',
                          message: (noBio && !face)
                              ? 'Entrarás con tu contraseña de respaldo. Podrás vincular huella y rostro después en tu perfil.'
                              : 'Solo se pedirá el método que ya vinculaste. Puedes vincular el otro desde tu perfil.',
                        );
                        if (ok) store.finishEnrollment();
                      }
                    : null,
                child: const Text('Continuar por ahora'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.step,
    required this.kind,
    required this.icon,
    required this.title,
    required this.hint,
    required this.linked,
    required this.busy,
    required this.onTap,
  });

  final int step;
  final BioKind kind;
  final IconData icon;
  final String title;
  final String hint;
  final bool linked;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: busy ? null : onTap,
      gradient: linked ? Palette.hero : null,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: linked ? Colors.white.withValues(alpha: 0.18) : Palette.lilacSoft,
            ),
            child: Icon(icon, size: 34, color: linked ? Colors.white : Palette.purple),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Método $step',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: linked ? Palette.lilac : Palette.violet,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: linked ? Colors.white : Palette.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  linked ? 'Vinculado. Toca para volver a verificar.' : hint,
                  style: TextStyle(color: linked ? Palette.lilacSoft : Palette.inkMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            linked ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
            color: linked ? const Color(0xFF7EE2B8) : Palette.orchid,
            size: 28,
          ),
        ],
      ),
    );
  }
}
