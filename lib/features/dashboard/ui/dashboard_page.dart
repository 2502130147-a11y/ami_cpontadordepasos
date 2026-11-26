import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/palette.dart';
import '../../../shared/charts/charts.dart';
import '../../../shared/map/route_maps.dart';
import '../../../shared/utils/fmt.dart';
import '../../../shared/widgets/amatista_sheet.dart';
import '../../../shared/widgets/anime_sparkles.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/soft_card.dart';
import '../../../shared/widgets/wave_header.dart';
import '../../auth/data/account.dart';
import '../../auth/logic/auth_store.dart';
import '../../history/logic/history_store.dart';
import '../../history/ui/training_detail_page.dart';
import '../../tracking/ui/open_tracking.dart';
import 'goal_rings.dart';

/// Inicio: metas semanales, actividad de hoy, semana y último entrenamiento.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final acc = context.watch<AuthStore>().account;
    final h = context.watch<HistoryStore>();
    if (acc == null) return const SizedBox.shrink();

    final stepsGoal = acc.weeklyStepsGoal;
    final kmGoal = acc.weeklyKmGoal;
    final last = h.items.isEmpty ? null : h.items.first;
    final now = DateTime.now();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        WaveHeader(
          bottomSpace: 64,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const MascotAvatar(size: 54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Fmt.longDay(now),
                          style: const TextStyle(color: Palette.lilac, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hola, ${acc.firstName}',
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: Palette.lilac, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${h.streak} ${h.streak == 1 ? 'día' : 'días'}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  GoalRings(
                    outer: stepsGoal == 0 ? 0 : h.weekSteps / stepsGoal,
                    inner: kmGoal == 0 ? 0 : h.weekKm / kmGoal,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(stepsGoal == 0 ? 0 : h.weekSteps * 100 / stepsGoal).clamp(0, 999).toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        const Text('semana', style: TextStyle(color: Palette.lilacSoft, fontSize: 11)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GoalLine(
                          color: Colors.white,
                          label: 'Pasos',
                          value: '${Fmt.thousands(h.weekSteps)} / ${Fmt.thousands(stepsGoal)}',
                        ),
                        const SizedBox(height: 12),
                        _GoalLine(
                          color: Palette.orchid,
                          label: 'Kilómetros',
                          value: '${Fmt.one(h.weekKm)} / ${Fmt.one(kmGoal)}',
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _editGoals(context, acc),
                          child: const Row(
                            children: [
                              Icon(Icons.tune_rounded, color: Palette.lilac, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Editar metas',
                                style: TextStyle(color: Palette.lilac, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle('Hoy'),
              Row(
                children: [
                  Expanded(
                    child: MetricTile(
                      icon: Icons.directions_walk_rounded,
                      value: Fmt.thousands(h.todaySteps),
                      label: 'Pasos',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricTile(
                      icon: Icons.route_rounded,
                      value: Fmt.one(h.todayKm),
                      unit: 'km',
                      label: 'Distancia',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricTile(
                      icon: Icons.timer_rounded,
                      value: '${h.todayActiveMin}',
                      unit: 'min',
                      label: 'Activo',
                    ),
                  ),
                ],
              ),
              const SectionTitle('Esta semana'),
              SoftCard(
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
                child: WeekBars(values: h.weekDailySteps, highlight: now.weekday - 1),
              ),
              const SizedBox(height: 18),
              _AnimeStartCard(onTap: () => openTracking(context)),
              if (last != null) ...[
                const SectionTitle('Último entrenamiento'),
                SoftCard(
                  padding: EdgeInsets.zero,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => TrainingDetailPage(training: last)),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                        child: SizedBox(
                          height: 150,
                          child: IgnorePointer(child: RouteSnapshotMap(route: last.route, interactive: false)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${Fmt.date(last.startedAt)} · ${Fmt.time(last.startedAt)}',
                                    style: const TextStyle(color: Palette.inkMuted, fontSize: 12),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${Fmt.km(last.distanceM)} km en ${Fmt.minutes(last.durationSec)}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Palette.violet),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editGoals(BuildContext context, Account acc) async {
    var steps = acc.weeklyStepsGoal.toDouble().clamp(7000.0, 140000.0);
    var km = acc.weeklyKmGoal.clamp(5.0, 150.0);
    final save = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Metas semanales', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 18),
                Text('Pasos: ${Fmt.thousands(steps.round())}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Slider(
                  value: steps,
                  min: 7000,
                  max: 140000,
                  divisions: 133,
                  onChanged: (v) => setSheet(() => steps = v),
                ),
                const SizedBox(height: 8),
                Text('Kilómetros: ${km.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Slider(
                  value: km,
                  min: 5,
                  max: 150,
                  divisions: 145,
                  onChanged: (v) => setSheet(() => km = v),
                ),
                const SizedBox(height: 16),
                GradientButton(label: 'Guardar metas', onPressed: () => Navigator.pop(ctx, true)),
              ],
            ),
          ),
        ),
      ),
    );
    if (save != true || !context.mounted) return;
    await context.read<AuthStore>().update(
          acc.copyWith(weeklyStepsGoal: steps.round(), weeklyKmGoal: km.roundToDouble()),
        );
    if (context.mounted) showFlash(context, 'Metas actualizadas', kind: FlashKind.success);
  }
}

class _GoalLine extends StatelessWidget {
  const _GoalLine({required this.color, required this.label, required this.value});
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Palette.lilacSoft, fontSize: 12)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tarjeta para iniciar entrenamiento con la mascota estilo anime.
class _AnimeStartCard extends StatelessWidget {
  const _AnimeStartCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: 26,
            child: SoftCard(
              gradient: Palette.hero,
              onTap: onTap,
              padding: EdgeInsets.zero,
              child: const Stack(
                children: [
                  Positioned.fill(child: AnimeSparkles(count: 12, seed: 3)),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 150, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '¡Vamos a entrenar!',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Más fuerte que ayer. GPS, podómetro, acelerómetro y giroscopio.',
                          style: TextStyle(color: Palette.lilacSoft, fontSize: 12, height: 1.3),
                        ),
                        SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.play_circle_fill_rounded, color: Palette.lilac, size: 24),
                            SizedBox(width: 6),
                            Text(
                              'Iniciar entrenamiento',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: -4,
            bottom: 0,
            top: 0,
            child: IgnorePointer(
              child: Image.asset(
                Palette.mascotStronger,
                width: 160,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stack) => const SizedBox(width: 160),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
