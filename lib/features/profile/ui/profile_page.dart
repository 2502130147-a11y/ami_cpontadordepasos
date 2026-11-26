import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/palette.dart';
import '../../../shared/permissions/permission_gate.dart';
import '../../../shared/utils/fmt.dart';
import '../../../shared/widgets/amatista_sheet.dart';
import '../../../shared/widgets/anime_sparkles.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/soft_card.dart';
import '../../auth/data/account.dart';
import '../../auth/data/biometric_gateway.dart';
import '../../auth/logic/auth_store.dart';
import '../../auth/ui/face_flow.dart';
import '../../history/logic/history_store.dart';

/// Perfil: datos corporales, seguridad biométrica y gestión de datos.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final acc = auth.account;
    if (acc == null) return const SizedBox.shrink();
    final top = MediaQuery.paddingOf(context).top;

    return ListView(
      padding: EdgeInsets.fromLTRB(18, top + 18, 18, 120),
      children: [
        SoftCard(
          gradient: Palette.hero,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const MascotAvatar(size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      acc.name,
                      style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
                    ),
                    Text('@${acc.username}', style: const TextStyle(color: Palette.lilac)),
                    const SizedBox(height: 4),
                    Text(
                      'Miembro desde ${Fmt.date(acc.createdAt)}',
                      style: const TextStyle(color: Palette.lilacSoft, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ---------------- Datos corporales
        SectionTitle(
          'Datos corporales',
          action: TextButton(onPressed: () => _editBody(context, acc), child: const Text('Editar')),
        ),
        Row(
          children: [
            Expanded(child: MetricTile(icon: Icons.monitor_weight_rounded, value: Fmt.one(acc.weightKg), unit: 'kg', label: 'Peso')),
            const SizedBox(width: 10),
            Expanded(child: MetricTile(icon: Icons.height_rounded, value: acc.heightCm.toStringAsFixed(0), unit: 'cm', label: 'Estatura')),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(
                icon: Icons.straighten_rounded,
                value: (acc.strideM * 100).toStringAsFixed(0),
                unit: 'cm',
                label: 'Zancada',
              ),
            ),
          ],
        ),

        // ---------------- Seguridad
        const SectionTitle('Seguridad'),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Modo de acceso', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              SegmentedButton<AccessMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: AccessMode.dual, label: Text('Ambos'), icon: Icon(Icons.verified_user_rounded)),
                  ButtonSegment(value: AccessMode.fingerprint, label: Text('Huella'), icon: Icon(Icons.fingerprint_rounded)),
                  ButtonSegment(value: AccessMode.face, label: Text('Rostro'), icon: Icon(Icons.face_rounded)),
                ],
                selected: {acc.accessMode},
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: Palette.purple,
                  selectedForegroundColor: Colors.white,
                  foregroundColor: Palette.purple,
                  side: const BorderSide(color: Palette.lilacLine),
                ),
                onSelectionChanged: (s) async {
                  await auth.update(acc.copyWith(accessMode: s.first));
                  if (context.mounted) {
                    showFlash(context, 'Modo de acceso: ${s.first.label}', kind: FlashKind.success);
                  }
                },
              ),
              const SizedBox(height: 16),
              _BioRow(
                icon: Icons.fingerprint_rounded,
                title: 'Huella dactilar',
                linked: acc.fingerLinked,
                busy: auth.busy,
                onTap: () => _link(context, BioKind.fingerprint),
              ),
              const Divider(height: 22, color: Palette.lilacSoft),
              _BioRow(
                icon: Icons.face_retouching_natural_rounded,
                title: 'Reconocimiento facial',
                linked: acc.faceLinked,
                busy: auth.busy,
                onTap: () => _link(context, BioKind.face),
              ),
              if (!auth.support.ready) ...[
                const SizedBox(height: 12),
                const Text(
                  'Este teléfono no tiene huella registrada. El rostro funciona con la cámara frontal.',
                  style: TextStyle(color: Palette.warning, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _changePassword(context),
                icon: const Icon(Icons.key_rounded),
                label: const Text('Contraseña'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: auth.lock,
                icon: const Icon(Icons.lock_rounded),
                label: const Text('Bloquear'),
              ),
            ),
          ],
        ),

        // ---------------- Datos
        const SectionTitle('Mis datos'),
        SoftCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.delete_sweep_rounded, color: Palette.violet),
                title: const Text('Borrar historial', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Elimina todos los entrenamientos guardados'),
                onTap: () async {
                  final ok = await confirmAction(
                    context,
                    title: 'Borrar historial',
                    message: 'Se eliminarán todos tus entrenamientos. No se puede deshacer.',
                    confirm: 'Borrar',
                    destructive: true,
                  );
                  if (!ok || !context.mounted) return;
                  await context.read<HistoryStore>().clear();
                  if (context.mounted) showFlash(context, 'Historial borrado');
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove_rounded, color: Palette.danger),
                title: const Text(
                  'Eliminar perfil',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Palette.danger),
                ),
                subtitle: const Text('Borra tu cuenta local y todo tu historial'),
                onTap: () async {
                  final ok = await confirmAction(
                    context,
                    title: 'Eliminar perfil',
                    message: 'Se borrarán tu perfil y tu historial de este teléfono. No se puede deshacer.',
                    confirm: 'Eliminar todo',
                    destructive: true,
                  );
                  if (!ok || !context.mounted) return;
                  final history = context.read<HistoryStore>();
                  await auth.deleteEverything();
                  history.forget();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'Amatista 1.0 · UPFIM · Desarrollo de Aplicaciones Móviles',
            style: TextStyle(color: Palette.inkMuted, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Future<void> _link(BuildContext context, BioKind kind) async {
    final auth = context.read<AuthStore>();
    final ok = await PermissionGate.explainBiometrics(context);
    if (!ok || !context.mounted) return;
    if (kind == BioKind.face) {
      await enrollFace(context);
      return;
    }
    await auth.refreshSupport();
    if (!context.mounted) return;
    if (!auth.support.ready) {
      showFlash(context, 'Registra tu huella en los ajustes del teléfono.', kind: FlashKind.error);
      return;
    }
    final r = await auth.link(kind);
    if (context.mounted) showFlash(context, r.message, kind: r.ok ? FlashKind.success : FlashKind.error);
  }

  Future<void> _editBody(BuildContext context, Account acc) async {
    final w = TextEditingController(text: Fmt.one(acc.weightKg));
    final h = TextEditingController(text: acc.heightCm.toStringAsFixed(0));
    final name = TextEditingController(text: acc.name);
    var sex = acc.sex;
    final form = GlobalKey<FormState>();
    double? parse(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.viewInsetsOf(ctx).bottom + 20),
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Editar perfil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.badge_rounded)),
                  validator: (v) => (v == null || v.trim().length < 3) ? 'Escribe tu nombre' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: w,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Peso (kg)'),
                        validator: (v) {
                          final n = parse(v ?? '');
                          return (n == null || n < 25 || n > 300) ? '25 a 300' : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: h,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Estatura (cm)'),
                        validator: (v) {
                          final n = parse(v ?? '');
                          return (n == null || n < 100 || n > 250) ? '100 a 250' : null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (code, label) in const [('F', 'Mujer'), ('M', 'Hombre')])
                      ChoiceChip(
                        label: Text(label),
                        selected: sex == code,
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          color: sex == code ? Colors.white : Palette.ink,
                          fontWeight: FontWeight.w700,
                        ),
                        onSelected: (_) => setSheet(() => sex = code),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Guardar cambios',
                  onPressed: () {
                    if (form.currentState?.validate() ?? false) Navigator.pop(ctx, true);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (save == true && context.mounted) {
      await context.read<AuthStore>().update(
            acc.copyWith(
              name: name.text.trim(),
              weightKg: parse(w.text),
              heightCm: parse(h.text),
              sex: sex,
            ),
          );
      if (context.mounted) showFlash(context, 'Perfil actualizado', kind: FlashKind.success);
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final cur = TextEditingController();
    final next = TextEditingController();
    final form = GlobalKey<FormState>();
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.viewInsetsOf(ctx).bottom + 20),
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Cambiar contraseña', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextFormField(
                controller: cur,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña actual', prefixIcon: Icon(Icons.key_rounded)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nueva contraseña', prefixIcon: Icon(Icons.key_rounded)),
                validator: (v) {
                  final t = v ?? '';
                  if (t.length < 8) return 'Mínimo 8 caracteres';
                  if (!RegExp(r'[A-Za-z]').hasMatch(t) || !RegExp(r'\d').hasMatch(t)) {
                    return 'Combina letras y números';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Actualizar',
                onPressed: () {
                  if (form.currentState?.validate() ?? false) Navigator.pop(ctx, true);
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (save == true && context.mounted) {
      final ok = await context.read<AuthStore>().changePassword(cur.text, next.text);
      if (context.mounted) {
        showFlash(
          context,
          ok ? 'Contraseña actualizada' : 'La contraseña actual no es correcta',
          kind: ok ? FlashKind.success : FlashKind.error,
        );
      }
    }
  }
}

class _BioRow extends StatelessWidget {
  const _BioRow({
    required this.icon,
    required this.title,
    required this.linked,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool linked;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconBadge(icon, size: 42, gradient: linked ? Palette.button : Palette.lilacButton),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                linked ? 'Vinculado' : 'Sin vincular',
                style: TextStyle(
                  fontSize: 12,
                  color: linked ? Palette.success : Palette.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: busy ? null : onTap,
          child: Text(linked ? 'Verificar' : 'Vincular'),
        ),
      ],
    );
  }
}
