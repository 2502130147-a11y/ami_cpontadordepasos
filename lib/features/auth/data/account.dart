/// Cómo se desbloquea el perfil.
enum AccessMode {
  dual, // huella + rostro (por defecto)
  fingerprint, // solo huella
  face; // solo rostro

  String get label => switch (this) {
        AccessMode.dual => 'Huella + rostro',
        AccessMode.fingerprint => 'Solo huella',
        AccessMode.face => 'Solo rostro',
      };
}

class Account {
  const Account({
    required this.name,
    required this.username,
    required this.passHash,
    required this.salt,
    required this.weightKg,
    required this.heightCm,
    required this.sex,
    required this.weeklyStepsGoal,
    required this.weeklyKmGoal,
    required this.accessMode,
    required this.fingerLinked,
    required this.faceLinked,
    required this.createdAt,
    this.faceTemplate,
  });

  final String name;
  final String username;
  final String passHash;
  final String salt;
  final double weightKg;
  final double heightCm;
  final String sex; // 'F' | 'M'
  final int weeklyStepsGoal;
  final double weeklyKmGoal;
  final AccessMode accessMode;
  final bool fingerLinked;
  final bool faceLinked;
  final DateTime createdAt;

  /// Plantilla del rostro (JSON) creada con la cámara; null si no hay.
  final String? faceTemplate;

  /// Longitud de zancada estimada a partir de la estatura.
  double get strideM => heightCm * (sex == 'F' ? 0.413 : 0.415) / 100;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? name : parts.first;
  }

  Account copyWith({
    String? name,
    String? passHash,
    String? salt,
    double? weightKg,
    double? heightCm,
    String? sex,
    int? weeklyStepsGoal,
    double? weeklyKmGoal,
    AccessMode? accessMode,
    bool? fingerLinked,
    bool? faceLinked,
    String? faceTemplate,
    bool clearFace = false,
  }) {
    return Account(
      name: name ?? this.name,
      username: username,
      passHash: passHash ?? this.passHash,
      salt: salt ?? this.salt,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      sex: sex ?? this.sex,
      weeklyStepsGoal: weeklyStepsGoal ?? this.weeklyStepsGoal,
      weeklyKmGoal: weeklyKmGoal ?? this.weeklyKmGoal,
      accessMode: accessMode ?? this.accessMode,
      fingerLinked: fingerLinked ?? this.fingerLinked,
      faceLinked: faceLinked ?? this.faceLinked,
      createdAt: createdAt,
      faceTemplate: clearFace ? null : (faceTemplate ?? this.faceTemplate),
    );
  }

  Map<String, Object?> toRow() => {
        'id': 1,
        'name': name,
        'username': username,
        'pass_hash': passHash,
        'salt': salt,
        'weight_kg': weightKg,
        'height_cm': heightCm,
        'sex': sex,
        'weekly_steps_goal': weeklyStepsGoal,
        'weekly_km_goal': weeklyKmGoal,
        'access_mode': accessMode.name,
        'finger_linked': fingerLinked ? 1 : 0,
        'face_linked': faceLinked ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'face_template': faceTemplate,
      };

  factory Account.fromRow(Map<String, Object?> r) {
    final modeName = r['access_mode'] as String? ?? 'dual';
    final template = r['face_template'] as String?;
    return Account(
      name: r['name'] as String,
      username: r['username'] as String,
      passHash: r['pass_hash'] as String,
      salt: r['salt'] as String,
      weightKg: (r['weight_kg'] as num).toDouble(),
      heightCm: (r['height_cm'] as num).toDouble(),
      sex: r['sex'] as String,
      weeklyStepsGoal: (r['weekly_steps_goal'] as num).toInt(),
      weeklyKmGoal: (r['weekly_km_goal'] as num).toDouble(),
      accessMode: AccessMode.values.firstWhere(
        (m) => m.name == modeName,
        orElse: () => AccessMode.dual,
      ),
      fingerLinked: (r['finger_linked'] as num) == 1,
      // El rostro solo cuenta como vinculado si existe su plantilla.
      faceLinked: (r['face_linked'] as num) == 1 && template != null && template.isNotEmpty,
      createdAt: DateTime.fromMillisecondsSinceEpoch((r['created_at'] as num).toInt()),
      faceTemplate: template,
    );
  }
}
