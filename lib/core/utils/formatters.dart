/// Formato de números, duraciones y fechas (en español, sin paquete `intl`).
class Formatters {
  Formatters._();

  static const List<String> _months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  // DateTime.weekday: 1 = lunes ... 7 = domingo
  static const List<String> _weekdays = [
    'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom',
  ];

  static String two(int n) => n.toString().padLeft(2, '0');

  /// 65 s -> "01:05"   |   3725 s -> "1:02:05"
  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  /// 850 -> "850 m"   |   1250 -> "1.25 km"
  static String distance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  /// Solo el número en km, para tarjetas con unidad aparte.
  static String kilometers(double meters) =>
      (meters / 1000).toStringAsFixed(2);

  /// m/s -> km/h con un decimal.
  static String speedKmh(double metersPerSecond) =>
      (metersPerSecond * 3.6).toStringAsFixed(1);

  static String calories(double kcal) => kcal.round().toString();

  /// 12345 -> "12,345"
  static String integer(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return n < 0 ? '-$buf' : buf.toString();
  }

  static String date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  static String time(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

  static String dateTime(DateTime d) => '${date(d)} · ${time(d)}';

  static String weekdayShort(DateTime d) => _weekdays[d.weekday - 1];

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// "Hoy", "Ayer" o la fecha.
  static String relativeDay(DateTime d) {
    final today = startOfDay(DateTime.now());
    final diff = today.difference(startOfDay(d)).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    return date(d);
  }

  /// Clave de día "2026-11-24" para agrupar pasos por día.
  static String dayKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
}