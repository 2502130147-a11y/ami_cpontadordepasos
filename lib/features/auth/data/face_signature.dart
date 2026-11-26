import 'dart:convert';
import 'dart:math' as math;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Plantilla facial guardada en el teléfono (nunca se guarda la foto).
///
/// Es un vector con la forma del contorno del rostro y de la nariz,
/// normalizado respecto a los ojos (posición, giro y escala), más el umbral
/// de aceptación calculado para esta persona durante el registro.
class FaceTemplate {
  const FaceTemplate({required this.vector, required this.threshold});

  final List<double> vector;
  final double threshold;

  String encode() => jsonEncode({'v': vector, 't': threshold});

  static FaceTemplate? tryDecode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final v = (m['v'] as List).map((e) => (e as num).toDouble()).toList();
      final t = (m['t'] as num).toDouble();
      if (v.isEmpty) return null;
      return FaceTemplate(vector: v, threshold: t);
    } catch (_) {
      return null;
    }
  }
}

/// Firma geométrica del rostro a partir de los contornos de ML Kit.
abstract final class FaceSignature {
  /// El rostro está de frente (necesario para comparar).
  static bool isFrontal(Face f) =>
      (f.headEulerAngleY ?? 99).abs() < 12 &&
      (f.headEulerAngleZ ?? 99).abs() < 12 &&
      (f.headEulerAngleX ?? 0).abs() < 18;

  static bool isNeutral(Face f) => (f.smilingProbability ?? 0) < 0.45;

  static bool isSmiling(Face f) => (f.smilingProbability ?? 0) > 0.72;

  /// Vector normalizado o null si faltan contornos.
  static List<double>? fromFace(Face f) {
    final oval = f.contours[FaceContourType.face]?.points;
    final leftEye = f.contours[FaceContourType.leftEye]?.points;
    final rightEye = f.contours[FaceContourType.rightEye]?.points;
    final noseBridge = f.contours[FaceContourType.noseBridge]?.points;
    final noseBottom = f.contours[FaceContourType.noseBottom]?.points;
    if (oval == null || leftEye == null || rightEye == null || noseBridge == null || noseBottom == null) {
      return null;
    }
    if (oval.length < 30 || leftEye.isEmpty || rightEye.isEmpty || noseBridge.isEmpty || noseBottom.isEmpty) {
      return null;
    }

    final (lx, ly) = _centroid(leftEye);
    final (rx, ry) = _centroid(rightEye);
    final eyeDist = math.sqrt((rx - lx) * (rx - lx) + (ry - ly) * (ry - ly));
    if (eyeDist < 20) return null; // rostro demasiado lejos

    final mx = (lx + rx) / 2;
    final my = (ly + ry) / 2;
    final angle = math.atan2(ry - ly, rx - lx);
    final c = math.cos(-angle);
    final s = math.sin(-angle);

    final out = <double>[];
    void add(List<math.Point<int>> pts) {
      for (final p in pts) {
        final dx = p.x - mx;
        final dy = p.y - my;
        out
          ..add((dx * c - dy * s) / eyeDist)
          ..add((dx * s + dy * c) / eyeDist);
      }
    }

    add(oval);
    add(noseBridge);
    add(noseBottom);
    return out;
  }

  /// Distancia media entre los puntos de dos firmas (0 = idénticas).
  static double distance(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return double.infinity;
    var sum = 0.0;
    for (var i = 0; i + 1 < a.length; i += 2) {
      final dx = a[i] - b[i];
      final dy = a[i + 1] - b[i + 1];
      sum += math.sqrt(dx * dx + dy * dy);
    }
    return sum / (a.length / 2);
  }

  /// Promedia varias muestras y calcula un umbral personal.
  static FaceTemplate? buildTemplate(List<List<double>> samples) {
    if (samples.length < 3) return null;
    final n = samples.first.length;
    if (samples.any((s) => s.length != n)) return null;
    final avg = List<double>.filled(n, 0);
    for (final s in samples) {
      for (var i = 0; i < n; i++) {
        avg[i] += s[i] / samples.length;
      }
    }
    final spread = samples.map((s) => distance(s, avg)).reduce((a, b) => a + b) / samples.length;
    final threshold = (spread * 3 + 0.035).clamp(0.05, 0.12).toDouble();
    return FaceTemplate(vector: avg, threshold: threshold);
  }

  /// Porcentaje de coincidencia para mostrar en pantalla.
  static int matchPercent(double d, double threshold) =>
      ((1 - d / (threshold * 2)).clamp(0.0, 1.0) * 100).round();

  static (double, double) _centroid(List<math.Point<int>> pts) {
    var x = 0.0, y = 0.0;
    for (final p in pts) {
      x += p.x;
      y += p.y;
    }
    return (x / pts.length, y / pts.length);
  }
}
