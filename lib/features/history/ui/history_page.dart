import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/theme/palette.dart';
import '../../../shared/charts/charts.dart';
import '../../../shared/utils/fmt.dart';
import '../../../shared/widgets/amatista_sheet.dart';
import '../../../shared/widgets/soft_card.dart';
import '../data/training.dart';
import '../logic/history_store.dart';
import 'training_detail_page.dart';

/// Historial de entrenamientos guardados en SQLite, agrupados por mes.
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final h = context.watch<HistoryStore>();
    final top = MediaQuery.paddingOf(context).top;

    // Agrupar por mes
    final groups = <String, List<Training>>{};
    for (final t in h.items) {
      groups.putIfAbsent(Fmt.monthYear(t.startedAt), () => []).add(t);
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(18, top + 18, 18, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Historial', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text(
                  'Tus sesiones guardadas en el teléfono',
                  style: TextStyle(color: Palette.inkMuted),
                ),
                const SizedBox(height: 16),
                SoftCard(
                  gradient: Palette.hero,
                  child: Row(
                    children: [
                      _Total(value: '${h.items.length}', label: 'Sesiones'),
                      _Total(value: Fmt.one(h.totalKm), label: 'Kilómetros'),
                      _Total(value: Fmt.thousands(h.totalSteps), label: 'Pasos'),
                      _Total(value: '${(h.totalSec / 3600).toStringAsFixed(1)} h', label: 'Tiempo'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (h.loading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (h.items.isEmpty)
          const SliverFillRemaining(hasScrollBody: false, child: _Empty())
        else
          for (final entry in groups.entries) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              sliver: SliverToBoxAdapter(child: SectionTitle(entry.key)),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverList.separated(
                itemCount: entry.value.length,
                separatorBuilder: (c, i) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _TrainingCard(training: entry.value[i]),
              ),
            ),
          ],
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Palette.lilacSoft, fontSize: 11)),
        ],
      ),
    );
  }
}

class _TrainingCard extends StatelessWidget {
  const _TrainingCard({required this.training});
  final Training training;

  @override
  Widget build(BuildContext context) {
    final t = training;
    return Dismissible(
      key: ValueKey('t${t.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Palette.danger.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(26),
        ),
        child: const Icon(Icons.delete_rounded, color: Palette.danger),
      ),
      confirmDismiss: (_) => confirmAction(
        context,
        title: 'Eliminar entrenamiento',
        message: 'Se borrará del historial de forma permanente.',
        confirm: 'Eliminar',
        destructive: true,
      ),
      onDismissed: (_) {
        if (t.id != null) context.read<HistoryStore>().remove(t.id!);
        showFlash(context, 'Entrenamiento eliminado');
      },
      child: SoftCard(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TrainingDetailPage(training: t)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Palette.lilacSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${t.startedAt.day}',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Palette.purple),
                      ),
                      Text(
                        Fmt.weekday(t.startedAt).substring(0, 3),
                        style: const TextStyle(fontSize: 11, color: Palette.violet, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${Fmt.km(t.distanceM)} km · ${Fmt.thousands(t.steps)} pasos',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${Fmt.time(t.startedAt)} · ${Fmt.minutes(t.durationSec)} · ${t.kcal.toStringAsFixed(0)} kcal',
                        style: const TextStyle(color: Palette.inkMuted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(
                  t.route.length >= 2 ? Icons.map_rounded : Icons.location_disabled_rounded,
                  color: Palette.orchid,
                ),
              ],
            ),
            const SizedBox(height: 12),
            EffortSplitBar(restSec: t.restSec, walkSec: t.walkSec, jogSec: t.jogSec, height: 8),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _EmptyMascot(),
          SizedBox(height: 12),
          Text('Aún no hay entrenamientos', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          SizedBox(height: 6),
          Text(
            'Toca el botón central para registrar tu primera sesión.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Palette.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _EmptyMascot extends StatelessWidget {
  const _EmptyMascot();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      Palette.mascotStronger,
      height: 200,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stack) =>
          const Icon(Icons.history_toggle_off_rounded, size: 64, color: Palette.lilac),
    );
  }
}
