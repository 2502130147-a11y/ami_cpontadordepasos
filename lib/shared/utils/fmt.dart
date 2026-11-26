/// Formatos de texto en español (sin dependencias externas).
abstract final class Fmt {
  static const _months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic', //
  ];
  static const _monthsLong = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', //
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  static const _days = [
    'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo', //
  ];
  static const weekLetters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  static String two(int n) => n.toString().padLeft(2, '0');

  static String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// 75 -> "01:15", 3725 -> "1:02:05"
  static String clock(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  /// 3900 -> "1 h 5 min"
  static String minutes(int sec) {
    final m = (sec / 60).round();
    if (m < 60) return '$m min';
    return '${m ~/ 60} h ${m % 60} min';
  }

  static String km(double meters) => (meters / 1000).toStringAsFixed(2);

  static String one(double v) => v.toStringAsFixed(1);

  /// 12345 -> "12,345"
  static String thousands(int n) {
    final s = n.abs().toString();
    final b = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  /// Ritmo en min/km -> 5'30"
  static String pace(double minPerKm) {
    if (minPerKm <= 0 || minPerKm.isNaN || minPerKm.isInfinite || minPerKm > 60) {
      return "--'--\"";
    }
    var m = minPerKm.floor();
    var s = ((minPerKm - m) * 60).round();
    if (s == 60) {
      m++;
      s = 0;
    }
    return "$m'${two(s)}\"";
  }

  static String date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  static String time(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

  /// "Miércoles, 25 de noviembre"
  static String longDay(DateTime d) =>
      '${cap(_days[d.weekday - 1])}, ${d.day} de ${_monthsLong[d.month - 1]}';

  static String weekday(DateTime d) => cap(_days[d.weekday - 1]);

  /// "Noviembre 2026"
  static String monthYear(DateTime d) => '${cap(_monthsLong[d.month - 1])} ${d.year}';
}
