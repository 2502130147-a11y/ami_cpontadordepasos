import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/palette.dart';
import '../../../shared/charts/charts.dart';
import '../../../shared/widgets/soft_card.dart';
import '../../tracking/logic/effort.dart';
import '../../tracking/logic/motion_hub.dart';
import '../../tracking/ui/sensor_widgets.dart';

/// Laboratorio: acelerómetro y giroscopio en vivo, sin iniciar una sesión.
/// Los streams existen solo mientras esta pestaña está visible y la app
/// está en primer plano.
class SensorLabPage extends StatefulWidget {
  const SensorLabPage({super.key});

  @override
  State<SensorLabPage> createState() => _SensorLabPageState();
}

class _SensorLabPageState extends State<SensorLabPage> with WidgetsBindingObserver {
  final MotionHub _hub = MotionHub();
  final List<double> _mag = [];
  Timer? _timer;
  int _ticks = 0;
  bool _live = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _stop();
    }
  }

  void _start() {
    if (_live) return;
    _live = true;
    _ticks = 0;
    _hub.startMotion();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _ticks++;
      if (_ticks == 30) _hub.checkHealth();
      _mag.add(_hub.magnitude - MotionHub.g);
      if (_mag.length > 80) _mag.removeAt(0);
      if (mounted) setState(() {});
    });
    if (mounted) setState(() {});
  }

  void _stop() {
    _live = false;
    _timer?.cancel();
    _timer = null;
    _hub.stopMotion();
  }

  @override
  Widget build(BuildContext context) {
    final h = _hub;
    final top = MediaQuery.paddingOf(context).top;
    final effort = Effort.fromLevel(h.effortLevel);
    return ListView(
      padding: EdgeInsets.fromLTRB(18, top + 18, 18, 120),
      children: [
        const Text('Sensores en vivo', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text(
          'Mueve o gira el teléfono. Al cambiar de pestaña los sensores se liberan.',
          style: TextStyle(color: Palette.inkMuted),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Status('Acelerómetro', ok: h.accelSeen, failed: h.accelFailed),
            _Status('Giroscopio', ok: h.gyroSeen, failed: h.gyroFailed),
            _Status(_live ? 'Escuchando' : 'En pausa', ok: _live, failed: false),
          ],
        ),
        const SizedBox(height: 16),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconBadge(Icons.vibration_rounded, size: 36),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Acelerómetro', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  ),
                  Icon(effort.icon, color: effort.color),
                  const SizedBox(width: 4),
                  Text(effort.label, style: TextStyle(fontWeight: FontWeight.w800, color: effort.color)),
                ],
              ),
              const SizedBox(height: 12),
              SeriesChart(
                values: _mag.map((v) => v.abs()).toList(),
                color: Palette.violet,
                height: 110,
                maxY: 12,
                animate: false,
                guides: const [Effort.walkFrom, Effort.jogFrom],
              ),
              const SizedBox(height: 4),
              Text(
                '|a| − g = ${(h.magnitude - MotionHub.g).abs().toStringAsFixed(2)} m/s²   ·   intensidad ${h.effortLevel.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12, color: Palette.inkMuted),
              ),
              const SizedBox(height: 14),
              AxisBars(x: h.ax, y: h.ay, z: h.az),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconBadge(Icons.threesixty_rounded, size: 36),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Giroscopio', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  ),
                  Text(
                    '${h.angularDeg.toStringAsFixed(0)} °/s',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.purple),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Center(child: _Phone3D(pitch: h.pitch, roll: h.roll, heading: h.heading)),
              const SizedBox(height: 18),
              AxisBars(x: h.gx, y: h.gy, z: h.gz, range: 6, unit: 'rad/s'),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Mini('Orientación', '${h.heading.toStringAsFixed(0)}°'),
                  _Mini('Cabeceo', '${h.pitch.toStringAsFixed(0)}°'),
                  _Mini('Alabeo', '${h.roll.toStringAsFixed(0)}°'),
                  _Mini('Giros', '${h.turns}'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Status extends StatelessWidget {
  const _Status(this.label, {required this.ok, required this.failed});
  final String label;
  final bool ok;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final color = failed ? Palette.danger : (ok ? Palette.success : Palette.warning);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Palette.lilacSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            failed ? Icons.cancel_rounded : (ok ? Icons.check_circle_rounded : Icons.hourglass_top_rounded),
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            failed ? '$label: no disponible' : label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Palette.plum)),
        Text(label, style: const TextStyle(fontSize: 11, color: Palette.inkMuted)),
      ],
    );
  }
}

/// Teléfono en 3D que copia la orientación real del dispositivo.
class _Phone3D extends StatelessWidget {
  const _Phone3D({required this.pitch, required this.roll, required this.heading});
  final double pitch;
  final double roll;
  final double heading;

  @override
  Widget build(BuildContext context) {
    const k = math.pi / 180;
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0015)
      ..rotateX((roll - 90).clamp(-80.0, 80.0) * k)
      ..rotateY(pitch.clamp(-80.0, 80.0) * k)
      ..rotateZ(-heading * k);
    return SizedBox(
      height: 170,
      width: 170,
      child: Center(
        child: Transform(
          alignment: Alignment.center,
          transform: m,
          child: Container(
            width: 78,
            height: 140,
            decoration: BoxDecoration(
              gradient: Palette.hero,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Palette.lilac, width: 3),
              boxShadow: [
                BoxShadow(color: Palette.purple.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 22,
                  height: 4,
                  decoration: BoxDecoration(color: Palette.lilac, borderRadius: BorderRadius.circular(4)),
                ),
                const Icon(Icons.diamond_rounded, color: Palette.lilac, size: 26),
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Palette.lilac, width: 2)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
