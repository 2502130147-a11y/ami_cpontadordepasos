import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/palette.dart';
import '../../../shared/charts/charts.dart';
import '../../../shared/map/route_maps.dart';
import '../../../shared/utils/fmt.dart';
import '../../../shared/widgets/amatista_sheet.dart';
import '../../../shared/widgets/soft_card.dart';
import '../../tracking/logic/effort.dart';
import '../data/training.dart';
import '../logic/history_store.dart';

/// Resumen de un entrenamiento: ruta, métricas, sensores y gráficas.
class TrainingDetailPage extends StatelessWidget {
  const TrainingDetailPage({super.key, required this.training, this.justSaved = false});

  final Training training;
  final bool justSaved;

  Future<void> _delete(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: 'Eliminar entrenamiento',
      message: 'Se borrará del historial de forma permanente.',
      confirm: 'Eliminar',
      destructive: true,
    );
    if (!ok || !context.mounted || training.id == null) return;
    await context.read<HistoryStore>().remove(training.id!);
    if (!context.mounted) return;
    showFlash(context, 'Entrenamiento eliminado');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = training;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 320,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
                      child: RouteSnapshotMap(route: t.route),
                    ),
                  ),
                  Positioned(
                    top: top + 10,
                    left: 14,
                    right: 14,
                    child: Row(
                      children: [
                        _CircleAction(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).pop()),
                        const Spacer(),
                        if (t.id != null)
                          _CircleAction(
                            icon: Icons.delete_outline_rounded,
                            color: Palette.danger,
                            onTap: () => _delete(context),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
            sliver: SliverList.list(
              children: [
                if (justSaved)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: Palette.hero,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.emoji_events_rounded, color: Palette.lilac, size: 30),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '¡Buen trabajo! Tu sesión quedó guardada.',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  Fmt.longDay(t.startedAt),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${Fmt.time(t.startedAt)} – ${Fmt.time(t.endedAt)} · ${Fmt.minutes(t.durationSec)}',
                  style: const TextStyle(color: Palette.inkMuted),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.95,
                  children: [
                    MetricTile(icon: Icons.timer_rounded, value: Fmt.clock(t.durationSec), label: 'Duración'),
                    MetricTile(icon: Icons.directions_walk_rounded, value: Fmt.thousands(t.steps), label: 'Pasos'),
                    MetricTile(icon: Icons.route_rounded, value: Fmt.km(t.distanceM), unit: 'km', label: 'Distancia'),
                    MetricTile(icon: Icons.speed_rounded, value: Fmt.one(t.avgKmh), unit: 'km/h', label: 'Promedio'),
                    MetricTile(icon: Icons.bolt_rounded, value: Fmt.one(t.maxKmh), unit: 'km/h', label: 'Máxima'),
                    MetricTile(
                      icon: Icons.local_fire_department_rounded,
                      value: t.kcal.toStringAsFixed(0),
                      unit: 'kcal',
                      label: 'Calorías',
                    ),
                  ],
                ),
                const SectionTitle('Intensidad (acelerómetro)'),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EffortSplitBar(restSec: t.restSec, walkSec: t.walkSec, jogSec: t.jogSec),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          _Legend(EffortSplitBar.restColor, Effort.rest.label, t.restSec),
                          _Legend(EffortSplitBar.walkColor, Effort.walk.label, t.walkSec),
                          _Legend(EffortSplitBar.jogColor, Effort.jog.label, t.jogSec),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SeriesChart(
                        values: t.intensity,
                        color: Palette.violet,
                        guides: const [Effort.walkFrom, Effort.jogFrom],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Líneas punteadas: umbral de caminata (0.8) y de trote (3.5 m/s²).',
                        style: TextStyle(fontSize: 11, color: Palette.inkMuted),
                      ),
                    ],
                  ),
                ),
                const SectionTitle('Velocidad (GPS)'),
                SoftCard(child: SeriesChart(values: t.speed, color: Palette.purple)),
                const SectionTitle('Orientación (giroscopio)'),
                Row(
                  children: [
                    Expanded(
                      child: MetricTile(icon: Icons.threesixty_rounded, value: '${t.turns}', label: 'Giros detectados'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MetricTile(
                        icon: Icons.rotate_right_rounded,
                        value: t.peakAngular.toStringAsFixed(0),
                        unit: '°/s',
                        label: 'Vel. angular pico',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: MetricTile(
                        icon: Icons.screen_rotation_alt_rounded,
                        value: t.maxTilt.toStringAsFixed(0),
                        unit: '°',
                        label: 'Inclinación máx.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${t.route.length} puntos GPS registrados',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Palette.inkMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label, this.sec);
  final Color color;
  final String label;
  final int sec;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label ${Fmt.minutes(sec)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap, this.color = Palette.purple});
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, color: color)),
      ),
    );
  }
}
