import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme/palette.dart';

/// Centro por defecto (Francisco I. Madero, Hidalgo) cuando aún no hay GPS.
const LatLng kFallbackCenter = LatLng(20.2394, -99.0944);
const String _tiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String _agent = 'com.example.app_contador_maye';

TileLayer _tileLayer() => TileLayer(urlTemplate: _tiles, userAgentPackageName: _agent);

Polyline _routeLine(List<LatLng> pts) => Polyline(
      points: pts,
      strokeWidth: 6,
      color: Palette.purple,
      borderStrokeWidth: 3,
      borderColor: Palette.lilac.withValues(alpha: 0.85),
      strokeCap: StrokeCap.round,
      strokeJoin: StrokeJoin.round,
    );

Widget _pin(IconData icon, Color bg) => Container(
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Icon(icon, size: 14, color: Colors.white),
    );

/// Punto azul… pero morado: posición actual con halo.
class _MeDot extends StatelessWidget {
  const _MeDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Palette.orchid.withValues(alpha: 0.30),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Palette.purple,
          border: Border.all(color: Colors.white, width: 3),
        ),
      ),
    );
  }
}

/// Mapa interactivo en vivo: sigue al usuario y dibuja la ruta.
class LiveRouteMap extends StatefulWidget {
  const LiveRouteMap({super.key, required this.route, required this.current, this.follow = true});

  final List<LatLng> route;
  final LatLng? current;
  final bool follow;

  @override
  State<LiveRouteMap> createState() => _LiveRouteMapState();
}

class _LiveRouteMapState extends State<LiveRouteMap> {
  final MapController _ctrl = MapController();
  bool _ready = false;
  bool _userMoved = false;

  @override
  void didUpdateWidget(covariant LiveRouteMap old) {
    super.didUpdateWidget(old);
    final c = widget.current;
    if (_ready && widget.follow && !_userMoved && c != null && c != old.current) {
      _ctrl.move(c, _ctrl.camera.zoom);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _recenter() {
    final c = widget.current;
    if (c == null) return;
    setState(() => _userMoved = false);
    _ctrl.move(c, 17);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _ctrl,
          options: MapOptions(
            initialCenter: widget.current ?? kFallbackCenter,
            initialZoom: widget.current == null ? 14 : 17,
            backgroundColor: Palette.lilacSoft,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () {
              _ready = true;
              final c = widget.current;
              if (c != null) _ctrl.move(c, 17);
            },
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture && !_userMoved) setState(() => _userMoved = true);
            },
          ),
          children: [
            _tileLayer(),
            if (widget.route.length >= 2) PolylineLayer(polylines: [_routeLine(widget.route)]),
            MarkerLayer(
              markers: [
                if (widget.route.isNotEmpty)
                  Marker(
                    point: widget.route.first,
                    width: 26,
                    height: 26,
                    child: _pin(Icons.flag_rounded, Palette.orchid),
                  ),
                if (widget.current != null)
                  Marker(point: widget.current!, width: 44, height: 44, child: const _MeDot()),
              ],
            ),
          ],
        ),
        if (_userMoved && widget.current != null)
          Positioned(
            right: 14,
            bottom: 52,
            child: FloatingActionButton.small(
              heroTag: null,
              backgroundColor: Colors.white,
              foregroundColor: Palette.purple,
              onPressed: _recenter,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
        const Positioned(
          left: 8,
          bottom: 4,
          child: Text('© OpenStreetMap', style: TextStyle(fontSize: 9, color: Colors.black54)),
        ),
      ],
    );
  }
}

/// Mapa de una ruta guardada (encuadra todo el recorrido).
class RouteSnapshotMap extends StatelessWidget {
  const RouteSnapshotMap({super.key, required this.route, this.interactive = true});

  final List<LatLng> route;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    if (route.isEmpty) {
      return Container(
        color: Palette.lilacSoft,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wrong_location_rounded, color: Palette.orchid, size: 36),
            SizedBox(height: 6),
            Text('Sin ruta GPS registrada', style: TextStyle(color: Palette.inkMuted)),
          ],
        ),
      );
    }
    final hasLine = route.length >= 2;
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: route.first,
            initialZoom: 16,
            backgroundColor: Palette.lilacSoft,
            initialCameraFit: hasLine
                ? CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(route),
                    padding: const EdgeInsets.all(40),
                    maxZoom: 18,
                  )
                : null,
            interactionOptions: InteractionOptions(
              flags: interactive
                  ? InteractiveFlag.all & ~InteractiveFlag.rotate
                  : InteractiveFlag.none,
            ),
          ),
          children: [
            _tileLayer(),
            if (hasLine) PolylineLayer(polylines: [_routeLine(route)]),
            MarkerLayer(
              markers: [
                Marker(
                  point: route.first,
                  width: 26,
                  height: 26,
                  child: _pin(Icons.flag_rounded, Palette.orchid),
                ),
                if (hasLine)
                  Marker(
                    point: route.last,
                    width: 26,
                    height: 26,
                    child: _pin(Icons.sports_score_rounded, Palette.plum),
                  ),
              ],
            ),
          ],
        ),
        const Positioned(
          left: 8,
          bottom: 4,
          child: Text('© OpenStreetMap', style: TextStyle(fontSize: 9, color: Colors.black54)),
        ),
      ],
    );
  }
}
