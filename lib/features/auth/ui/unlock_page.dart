import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/palette.dart';
import '../../../shared/widgets/amatista_sheet.dart';
import '../../../shared/widgets/anime_sparkles.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../data/biometric_gateway.dart';
import '../logic/auth_store.dart';
import 'face_flow.dart';

/// Desbloqueo en dos pasos: 1) huella, 2) rostro.
class UnlockPage extends StatefulWidget {
  const UnlockPage({super.key});

  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  final _pass = TextEditingController();
  bool _showPassword = false;
  String? _status;
  bool _statusOk = true;

  @override
  void dispose() {
    _pulse.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _verify(BioKind kind) async {
    final store = context.read<AuthStore>();
    final messenger = ScaffoldMessenger.of(context);

    // Rostro: reconocimiento propio con la cámara frontal.
    if (kind == BioKind.face) {
      final ok = await verifyFaceStep(context);
      if (!mounted) return;
      setState(() {
        _status = ok ? 'Rostro verificado correctamente' : 'No se pudo verificar tu rostro';
        _statusOk = ok;
      });
      return;
    }

    // Huella: diálogo biométrico del sistema.
    final r = await store.unlockStep(kind);
    final complete = store.status == AuthStatus.unlocked;
    showFlashWith(
      messenger,
      complete ? '¡Acceso concedido! Bienvenido(a), ${store.account?.firstName ?? ''}' : r.message,
      kind: r.ok ? FlashKind.success : FlashKind.error,
    );
    if (!mounted) return;
    setState(() {
      _status = r.message;
      _statusOk = r.ok;
    });
  }

  void _usePassword() {
    final ok = context.read<AuthStore>().unlockWithPassword(_pass.text);
    if (!ok) {
      setState(() {
        _status = 'Contraseña incorrecta';
        _statusOk = false;
      });
      showFlash(context, 'Contraseña incorrecta', kind: FlashKind.error);
    } else {
      showFlash(context, 'Acceso concedido con contraseña', kind: FlashKind.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AuthStore>();
    final acc = store.account;
    final needed = store.requiredKinds;
    final next = store.nextKind;
    final fingerOk = store.passed.contains(BioKind.fingerprint);
    final faceOk = store.passed.contains(BioKind.face);
    final needFinger = needed.contains(BioKind.fingerprint);
    final needFace = needed.contains(BioKind.face);
    final passwordOnly = needed.isEmpty;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: Palette.night),
        child: Stack(
          children: [
            const Positioned.fill(child: AnimeSparkles(count: 24)),
            SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
            children: [
              Row(
                children: [
                  const MascotAvatar(size: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hola de nuevo', style: TextStyle(color: Palette.lilac, fontSize: 13)),
                        Text(
                          acc?.name ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.diamond_rounded, color: Palette.lilac),
                ],
              ),
              const SizedBox(height: 40),
              Center(
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (ctx, child) => CustomPaint(
                      painter: _DualRingPainter(
                        t: _pulse.value,
                        leftOn: fingerOk,
                        rightOn: faceOk,
                        leftNeeded: needFinger,
                        rightNeeded: needFace,
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            passwordOnly
                                ? Icons.key_rounded
                                : next == BioKind.face
                                    ? Icons.face_retouching_natural_rounded
                                    : next == BioKind.fingerprint
                                        ? Icons.fingerprint_rounded
                                        : Icons.lock_open_rounded,
                            key: ValueKey('$next$passwordOnly'),
                            size: 84,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              if (!passwordOnly)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (needFinger) _StepChip(n: 1, label: 'Huella', done: fingerOk, active: next == BioKind.fingerprint),
                    if (needFinger && needFace)
                      Container(width: 26, height: 2, color: Palette.lilac.withValues(alpha: 0.5)),
                    if (needFace)
                      _StepChip(n: needFinger ? 2 : 1, label: 'Rostro', done: faceOk, active: next == BioKind.face),
                  ],
                ),
              const SizedBox(height: 18),
              Text(
                passwordOnly
                    ? 'No hay biometría vinculada en este teléfono.\nEntra con tu contraseña de respaldo.'
                    : next == BioKind.face
                        ? 'Ahora mira a la cámara frontal'
                        : 'Coloca tu dedo en el lector de huella',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Palette.lilacSoft, fontSize: 15, height: 1.4),
              ),
              if (_status != null) ...[
                const SizedBox(height: 14),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_statusOk ? const Color(0xFF7EE2B8) : const Color(0xFFFF9AB0))
                          .withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _statusOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          size: 18,
                          color: _statusOk ? const Color(0xFF7EE2B8) : const Color(0xFFFF9AB0),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(_status!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 30),
              if (!passwordOnly && next != null)
                GradientButton(
                  label: next == BioKind.face ? 'Verificar rostro' : 'Verificar huella',
                  icon: next == BioKind.face ? Icons.face_rounded : Icons.fingerprint_rounded,
                  gradient: Palette.lilacButton,
                  foreground: Palette.plum,
                  loading: store.busy,
                  onPressed: () => _verify(next),
                ),
              if (store.passwordAllowed) ...[
                const SizedBox(height: 14),
                if (!passwordOnly && !_showPassword)
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Palette.lilac),
                    onPressed: () => setState(() => _showPassword = true),
                    child: const Text('Usar contraseña de respaldo'),
                  ),
                if (passwordOnly || _showPassword) ...[
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    onSubmitted: (_) => _usePassword(),
                    decoration: const InputDecoration(
                      hintText: 'Contraseña',
                      prefixIcon: Icon(Icons.key_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GradientButton(
                    label: 'Entrar',
                    icon: Icons.login_rounded,
                    gradient: Palette.lilacButton,
                    foreground: Palette.plum,
                    onPressed: _usePassword,
                  ),
                ],
              ],
            ],
          ),
        ),
          ],
        ),
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.n, required this.label, required this.done, required this.active});

  final int n;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: done
            ? Palette.lilac
            : active
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: active ? Palette.lilac : Colors.transparent, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_rounded : (n == 1 ? Icons.looks_one_rounded : Icons.looks_two_rounded),
            size: 18,
            color: done ? Palette.plum : Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: done ? Palette.plum : Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Anillo partido en dos mitades: izquierda = huella, derecha = rostro.
class _DualRingPainter extends CustomPainter {
  _DualRingPainter({
    required this.t,
    required this.leftOn,
    required this.rightOn,
    required this.leftNeeded,
    required this.rightNeeded,
  });

  final double t;
  final bool leftOn;
  final bool rightOn;
  final bool leftNeeded;
  final bool rightNeeded;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 14;

    // Pulso
    final pulse = Paint()
      ..color = Palette.lilac.withValues(alpha: (1 - t) * 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(c, r * (0.75 + 0.3 * t), pulse);

    // Disco central
    canvas.drawCircle(c, r - 16, Paint()..color = Colors.white.withValues(alpha: 0.08));

    final rect = Rect.fromCircle(center: c, radius: r);
    void half(double start, bool on, bool needed) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..color = !needed
            ? Colors.white.withValues(alpha: 0.08)
            : on
                ? Palette.lilac
                : Colors.white.withValues(alpha: 0.22);
      canvas.drawArc(rect, start, math.pi - 0.3, false, p);
    }

    // Mitad izquierda (huella) de 90° a 270°, derecha (rostro) de 270° a 450°.
    half(math.pi / 2 + 0.15, leftOn, leftNeeded || !rightNeeded);
    half(-math.pi / 2 + 0.15, rightOn, rightNeeded || !leftNeeded);
  }

  @override
  bool shouldRepaint(covariant _DualRingPainter old) =>
      old.t != t || old.leftOn != leftOn || old.rightOn != rightOn;
}
