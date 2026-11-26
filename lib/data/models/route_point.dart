/// Un punto de la ruta: latitud, longitud y marca de tiempo.
class RoutePoint {
  const RoutePoint({
    required this.lat,
    required this.lon,
    required this.timestampMs,
  });

  final double lat;
  final double lon;
  final int timestampMs;

  Map<String, dynamic> toMap() => {'a': lat, 'o': lon, 't': timestampMs};

  factory RoutePoint.fromMap(Map<String, dynamic> m) => RoutePoint(
    lat: (m['a'] as num).toDouble(),
    lon: (m['o'] as num).toDouble(),
    timestampMs: (m['t'] as num).toInt(),
  );
}