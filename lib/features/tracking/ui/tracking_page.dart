import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/palette.dart';
import '../../../shared/map/route_maps.dart';
import '../../../shared/permissions/permission_gate.dart';
import '../../../shared/utils/fmt.dart';
import '../../../shared/widgets/amatista_sheet.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/soft_card.dart';
import '../../history/logic/history_store.dart';
import '../../history/ui/training_detail_page.dart';
import '../logic/tracking_store.dart';
import 'sensor_widgets.dart';

/// Entrenamiento en vivo: mapa + métricas + sensores.
class TrackingPage extends StatelessWidget {
  const TrackingPage({super.key, required this.strideM, required this.weightKg});

  final double strideM;
  final double weightKg;

  @override
  Widget build(BuildContext context) {
    // El store vive solo mientras esta pantalla existe: al salir se
    // ejecuta dispose() y se cancelan todos los sensores.
    return ChangeNotifierProvider(
      create: (_) => TrackingStore(strideM: strideM, weightKg: weightKg),
      child: const _TrackingView(),
    );
  }
}

class _TrackingView extends StatefulWidget {
  const _TrackingView();

  @override
  State<_TrackingView> createState() => _TrackingViewState();
}

class _TrackingViewState extends State<_TrackingView> with WidgetsBindingObserver {
  TrainingGrants? _grants;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _askPermissions());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Segundo plano: se liberan acelerómetro y giroscopio.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final store = context.read<TrackingStore>();
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (!store.inBackground) store.toBackground();
      case AppLifecycleState.resumed:
        store.toForeground();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _askPermissions() async {
    final g = await PermissionGate.forTraining(context);
    if (mounted) setState(() => _grants = g);
  }

  void _start() {
    final g = _grants ?? (location: false, activity: false);
    context.read<TrackingStore>().begin(location: g.location, activity: g.activity);
    if (!g.location) {
      showFlash(context, 'Sin ubicación: la distancia se estimará con tus pasos.');
    } else if (!g.activity) {
      showFlash(context, 'Sin permiso de actividad: los pasos se contarán con el acelerómetro.');
    }
  }

  Future<void> _finish() async {
    if (_saving) return;
    final store = context.read<TrackingStore>();
    final history = context.read<HistoryStore>();
    final nav = Navigator.of(context);
    final t = store.finish();
    if (t.durationSec < 5) {
      showFlash(context, 'La sesión fue muy corta y no se guardó.', kind: FlashKind.error);
      nav.pop();
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await history.add(t);
      if (!mounted) return;
      showFlash(context, 'Entrenamiento guardado en tu historial', kind: FlashKind.success);
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => TrainingDetailPage(training: saved, justSaved: true)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showFlash(context, 'No se pudo guardar el entrenamiento.', kind: FlashKind.error);
    }
  }

  Future<void> _onBack() async {
    final store = context.read<TrackingStore>();
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir del entrenamiento?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Puedes guardarlo en tu historial o descartarlo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'stay'), child: const Text('Seguir')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            style: TextButton.styleFrom(foregroundColor: Palette.danger),
            child: const Text('Descartar'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Guardar')),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'save') {
      await _finish();
    } else if (choice == 'discard') {
      store.pause();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<TrackingStore>();
    final ready = s.phase == SessionPhase.ready;
    final top = MediaQuery.paddingOf(context).top;

    return PopScope(
      canPop: ready || s.phase == SessionPhase.finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        body: Column(
          children: [
            // ---------------- Mapa
            Expanded(
              flex: 9,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
                      child: LiveRouteMap(route: s.gps.route, current: s.gps.current),
                    ),
                  ),
                  Positioned(
                    top: top + 10,
                    left: 14,
                    right: 14,
                    child: Row(
                      children: [
                        _RoundButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const Spacer(),
                        _GpsChip(store: s),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ---------------- Panel
            Expanded(
              flex: 11,
              child: ready ? _ReadyPanel(grants: _grants) : _LivePanel(store: s),
            ),
            _Controls(
              phase: s.phase,
              saving: _saving,
              canStart: _grants != null,
              onStart: _start,
              onPause: s.pause,
              onResume: s.resume,
              onFinish: _finish,
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Palette.purple.withValues(alpha: 0.3),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Palette.purple),
        ),
      ),
    );
  }
}

class _GpsChip extends StatelessWidget {
  const _GpsChip({required this.store});
  final TrackingStore store;

  @override
  Widget build(BuildContext context) {
    final g = store.gps;
    final (String text, Color dot) = !store.locationGranted && store.phase != SessionPhase.ready
        ? ('GPS sin permiso', Palette.danger)
        : !g.serviceOn
            ? ('GPS apagado', Palette.danger)
            : g.hasFix
                ? ('GPS ±${g.accuracyM.toStringAsFixed(0)} m', Palette.success)
                : g.active
                    ? ('Buscando señal…', Palette.warning)
                    : ('GPS en espera', Palette.lilac);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Palette.purple.withValues(alpha: 0.2), blurRadius: 10)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(width: 6),
          Text('${g.route.length} pts', style: const TextStyle(fontSize: 11, color: Palette.inkMuted)),
        ],
      ),
    );
  }
}

// ======================================================================
class _ReadyPanel extends StatelessWidget {
  const _ReadyPanel({required this.grants});
  final TrainingGrants? grants;

  @override
  Widget build(BuildContext context) {
    final g = grants;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      children: [
        const Text('Nueva sesión', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text(
          'Estos sensores se activarán al comenzar y se liberarán al pausar o salir.',
          style: TextStyle(color: Palette.inkMuted),
        ),
        const SizedBox(height: 16),
        _CheckRow(Icons.location_on_rounded, 'GPS y mapa en tiempo real', g?.location),
        _CheckRow(Icons.directions_walk_rounded, 'Podómetro (pasos)', g?.activity),
        const _CheckRow(Icons.speed_rounded, 'Acelerómetro (intensidad)', true),
        const _CheckRow(Icons.threesixty_rounded, 'Giroscopio (orientación y giros)', true),
        if (g != null && (!g.location || !g.activity))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: () async {
                final state = context.findAncestorStateOfType<_TrackingViewState>();
                await state?._askPermissions();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Volver a pedir permisos'),
            ),
          ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow(this.icon, this.text, this.ok);
  final IconData icon;
  final String text;
  final bool? ok;

  @override
  Widget build(BuildContext context) {
    final color = ok == null ? Palette.inkMuted : (ok! ? Palette.success : Palette.warning);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          IconBadge(icon, size: 38),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
          Icon(
            ok == null
                ? Icons.hourglass_top_rounded
                : ok!
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
            color: color,
          ),
        ],
      ),
    );
  }
}

// ======================================================================
class _LivePanel extends StatelessWidget {
  const _LivePanel({required this.store});
  final TrackingStore store;

  @override
  Widget build(BuildContext context) {
    final s = store;
    final m = s.motion;
    final paused = s.phase == SessionPhase.paused;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Fmt.clock(s.elapsed),
              style: const TextStyle(
                fontSize: 46,
                fontWeight: FontWeight.w900,
                color: Palette.plum,
                height: 1,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                paused ? 'EN PAUSA' : 'EN CURSO',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 12,
                  color: paused ? Palette.warning : Palette.success,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        EffortTrack(current: s.effort),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                icon: Icons.directions_walk_rounded,
                value: Fmt.thousands(s.steps),
                label: m.usingPedometer ? 'Pasos · podómetro' : 'Pasos · acelerómetro',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(
                icon: Icons.route_rounded,
                value: Fmt.km(s.distanceM),
                unit: 'km',
                label: s.distanceFromGps ? 'Distancia · GPS' : 'Distancia · pasos',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                icon: Icons.speed_rounded,
                value: Fmt.one(s.gps.speedKmh),
                unit: 'km/h',
                label: 'Ritmo ${Fmt.pace(s.paceMinKm)} /km',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(
                icon: Icons.local_fire_department_rounded,
                value: s.kcal.toStringAsFixed(0),
                unit: 'kcal',
                label: 'Calorías estimadas',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconBadge(Icons.vibration_rounded, size: 34),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Acelerómetro', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  Text(
                    m.accelFailed ? 'No disponible' : 'Intensidad ${m.effortLevel.toStringAsFixed(2)} m/s²',
                    style: const TextStyle(fontSize: 12, color: Palette.inkMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AxisBars(x: m.ax, y: m.ay, z: m.az),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconBadge(Icons.threesixty_rounded, size: 34),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Giroscopio', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  Text(
                    m.gyroFailed ? 'No disponible' : '${m.turns} giros',
                    style: const TextStyle(fontSize: 12, color: Palette.inkMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      GyroDial(headingDeg: m.heading, angularDeg: m.angularDeg, size: 118),
                      const SizedBox(height: 6),
                      Text('Orientación ${m.heading.toStringAsFixed(0)}°',
                          style: const TextStyle(fontSize: 12, color: Palette.inkMuted)),
                    ],
                  ),
                  Column(
                    children: [
                      TiltBubble(pitch: m.pitch, roll: m.roll, size: 118),
                      const SizedBox(height: 6),
                      Text('Inclinación ${m.pitch.toStringAsFixed(0)}° / ${m.roll.toStringAsFixed(0)}°',
                          style: const TextStyle(fontSize: 12, color: Palette.inkMuted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AxisBars(x: m.gx, y: m.gy, z: m.gz, range: 6, unit: 'rad/s'),
            ],
          ),
        ),
      ],
    );
  }
}

// ======================================================================
class _Controls extends StatelessWidget {
  const _Controls({
    required this.phase,
    required this.saving,
    required this.canStart,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
  });

  final SessionPhase phase;
  final bool saving;
  final bool canStart;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Palette.purple.withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: switch (phase) {
            SessionPhase.ready => GradientButton(
                label: canStart ? 'Comenzar entrenamiento' : 'Preparando sensores…',
                icon: Icons.play_arrow_rounded,
                onPressed: canStart ? onStart : null,
              ),
            SessionPhase.finished => const SizedBox(
                height: 56,
                child: Center(child: CircularProgressIndicator()),
              ),
            _ => Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      label: phase == SessionPhase.running ? 'Pausar' : 'Reanudar',
                      icon: phase == SessionPhase.running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      gradient: phase == SessionPhase.running ? Palette.lilacButton : Palette.button,
                      foreground: phase == SessionPhase.running ? Palette.plum : Colors.white,
                      onPressed: phase == SessionPhase.running ? onPause : onResume,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HoldToFinish(onFinished: onFinish, size: 64),
                      const SizedBox(height: 2),
                      const Text('Mantén', style: TextStyle(fontSize: 10, color: Palette.inkMuted)),
                    ],
                  ),
                ],
              ),
          },
        ),
      ),
    );
  }
}
