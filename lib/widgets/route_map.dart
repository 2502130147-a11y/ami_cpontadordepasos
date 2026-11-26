import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme/app_theme.dart';
import '../data/models/route_point.dart';

/// Mapa de OpenStreetMap (sin API key) con la ruta dibujada.
///
/// - Modo en vivo (`follow: true`): sigue al usuario. Si el usuario mueve el
///   mapa con el dedo, deja de seguirlo y aparece un botón para recentrar.
/// - Modo detalle (`follow: false`): se ajusta para mostrar toda la ruta,
///   con marcadores de inicio y de fin (`showEnd: true`).
class RouteMap extends StatefulWidget {
  const RouteMap({
    super.key,
    required this.route,
    this.current,
    this.follow = false,
    this.showEnd = false,
    this.emptyMessage,
  });

  final List<RoutePoint> route;
  final ({double lat, double lon})? current;
  final bool follow;
  final bool showEnd;

  /// Texto que se superpone cuando aún no hay ni ruta ni posición.
  final String? emptyMessage;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  static const double _followZoom = 17;
  static const LatLng _fallbackCenter = LatLng(19.4326, -99.1332);

  final MapController _controller = MapController();
  List<LatLng> _points = const [];
  bool _ready = false;
  bool _following = true;

  @override
  void initState() {
    super.initState();
    _syncPoints();
  }

  @override
  void didUpdateWidget(covariant RouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.route.length != _points.length) _syncPoints();

    final cur = widget.current;
    if (widget.follow && _following && cur != null && cur != oldWidget.current) {
      _scheduleMove(LatLng(cur.lat, cur.lon));
    }
  }

  /// La ruta solo crece: se agregan los puntos nuevos en vez de reconvertir todo.
  void _syncPoints() {
    final route = widget.route;
    if (route.length < _points.length) {
      _points = [for (final p in route) LatLng(p.lat, p.lon)];
    } else {
      _points = [
        ..._points,
        for (var i = _points.length; i < route.length; i++)
          LatLng(route[i].lat, route[i].lon),
      ];
    }
  }

  void _scheduleMove(LatLng target) {
    if (!_ready) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final zoom = _controller.camera.zoom;
      _controller.move(target, zoom < 15 ? _followZoom : zoom);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _pin(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
      ),
      child: Icon(icon, color: Colors.white, size: 16),
    );
  }

  Widget _userDot() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cur = widget.current;
    final hasAnything = _points.isNotEmpty || cur != null;

    final LatLng center = cur != null
        ? LatLng(cur.lat, cur.lon)
        : (_points.isNotEmpty ? _points.last : _fallbackCenter);

    final fit = !widget.follow && _points.length >= 2;

    final markers = <Marker>[
      if (_points.isNotEmpty)
        Marker(
          point: _points.first,
          width: 32,
          height: 32,
          child: _pin(Icons.flag_rounded, AppColors.success),
        ),
      if (widget.showEnd && _points.length > 1)
        Marker(
          point: _points.last,
          width: 32,
          height: 32,
          child: _pin(Icons.stop_rounded, AppColors.danger),
        ),
      if (widget.follow && cur != null)
        Marker(
          point: LatLng(cur.lat, cur.lon),
          width: 26,
          height: 26,
          child: _userDot(),
        ),
    ];

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: center,
            initialZoom: hasAnything ? _followZoom : 5,
            initialCameraFit: fit
                ? CameraFit.coordinates(
              coordinates: _points,
              padding: const EdgeInsets.all(44),
              maxZoom: 18,
            )
                : null,
            interactionOptions: InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () {
              _ready = true;
              final c = widget.current;
              if (widget.follow && c != null) {
                _scheduleMove(LatLng(c.lat, c.lon));
              }
            },
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture && widget.follow && _following) {
                setState(() => _following = false);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app_contador_maye',
            ),
            if (_points.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _points,
                    strokeWidth: 6,
                    color: const Color(0xFFFF5A1F),
                    borderStrokeWidth: 2,
                    borderColor: Colors.white,
                  ),
                ],
              ),
            MarkerLayer(markers: markers),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        if (!hasAnything && widget.emptyMessage != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    widget.emptyMessage!,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ),
            ),
          ),
        if (widget.follow && !_following && cur != null)
          Positioned(
            right: 12,
            bottom: 34,
            child: IconButton.filled(
              tooltip: 'Centrar en mi posición',
              onPressed: () {
                setState(() => _following = true);
                _scheduleMove(LatLng(cur.lat, cur.lon));
              },
              icon: const Icon(Icons.my_location_rounded),
            ),
          ),
      ],
    );
  }
}