import 'package:flutter/material.dart';

import '../../app/theme/palette.dart';
import '../dashboard/ui/dashboard_page.dart';
import '../history/ui/history_page.dart';
import '../lab/ui/sensor_lab_page.dart';
import '../profile/ui/profile_page.dart';
import '../tracking/ui/open_tracking.dart';

/// Contenedor principal con un "dock" flotante y botón central para entrenar.
///
/// Solo se construye la pestaña visible (no IndexedStack): al cambiar de
/// pestaña la anterior se destruye y, si tenía sensores activos (Sensores),
/// sus listeners se liberan en dispose().
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _items = [
    (Icons.space_dashboard_rounded, 'Inicio'),
    (Icons.history_rounded, 'Historial'),
    (Icons.sensors_rounded, 'Sensores'),
    (Icons.person_rounded, 'Perfil'),
  ];

  Widget _page(int i) => switch (i) {
        0 => const DashboardPage(),
        1 => const HistoryPage(),
        2 => const SensorLabPage(),
        _ => const ProfilePage(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: KeyedSubtree(key: ValueKey(_index), child: _page(_index)),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: SizedBox(
          height: 74,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                height: 66,
                decoration: BoxDecoration(
                  color: Palette.plum,
                  borderRadius: BorderRadius.circular(34),
                  boxShadow: [
                    BoxShadow(
                      color: Palette.plum.withValues(alpha: 0.35),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    _dockItem(0),
                    _dockItem(1),
                    const SizedBox(width: 76),
                    _dockItem(2),
                    _dockItem(3),
                  ],
                ),
              ),
              Positioned(
                bottom: 18,
                child: GestureDetector(
                  onTap: () => openTracking(context),
                  child: Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: Palette.lilacButton,
                      border: Border.all(color: Palette.mist, width: 5),
                      boxShadow: [
                        BoxShadow(
                          color: Palette.orchid.withValues(alpha: 0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dockItem(int i) {
    final (icon, label) = _items[i];
    final on = i == _index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _index = i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: on ? Palette.lilac : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 22, color: on ? Palette.plum : Palette.lilac),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                color: on ? Colors.white : Palette.lilac.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
