/// Sexo del usuario (se usa solo como dato de perfil).
enum Sex {
  male('Hombre'),
  female('Mujer'),
  other('Otro');

  const Sex(this.label);
  final String label;

  static Sex fromName(String? name) {
    return Sex.values.firstWhere(
          (s) => s.name == name,
      orElse: () => Sex.other,
    );
  }
}

class UserModel {
  const UserModel({
    this.id,
    required this.name,
    required this.username,
    required this.passwordHash,
    required this.salt,
    this.weightKg,
    this.heightCm,
    this.age,
    this.sex,
    this.dailyGoal = 10000,
    this.biometricEnabled = false,
    required this.createdAtMs,
  });

  final int? id;
  final String name;
  final String username;
  final String passwordHash;
  final String salt;
  final double? weightKg;
  final double? heightCm;
  final int? age;
  final Sex? sex;
  final int dailyGoal;
  final bool biometricEnabled;
  final int createdAtMs;

  /// ¿Ya tiene peso y estatura? Las cuentas viejas pueden no tenerlos.
  bool get hasBodyData =>
      weightKg != null && heightCm != null && weightKg! > 0 && heightCm! > 0;

  UserModel copyWith({
    int? id,
    String? name,
    String? username,
    String? passwordHash,
    String? salt,
    double? weightKg,
    double? heightCm,
    int? age,
    Sex? sex,
    int? dailyGoal,
    bool? biometricEnabled,
    int? createdAtMs,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name,
    'username': username,
    'password_hash': passwordHash,
    'salt': salt,
    'weight_kg': weightKg,
    'height_cm': heightCm,
    'age': age,
    'sex': sex?.name,
    'daily_goal': dailyGoal,
    'biometric_enabled': biometricEnabled ? 1 : 0,
    'created_at': createdAtMs,
  };

  factory UserModel.fromMap(Map<String, Object?> m) => UserModel(
    id: m['id'] as int?,
    name: m['name'] as String,
    username: m['username'] as String,
    passwordHash: m['password_hash'] as String,
    salt: m['salt'] as String,
    weightKg: (m['weight_kg'] as num?)?.toDouble(),
    heightCm: (m['height_cm'] as num?)?.toDouble(),
    age: (m['age'] as num?)?.toInt(),
    sex: m['sex'] == null ? null : Sex.fromName(m['sex'] as String?),
    dailyGoal: (m['daily_goal'] as num?)?.toInt() ?? 10000,
    biometricEnabled: (m['biometric_enabled'] as num?) == 1,
    createdAtMs: (m['created_at'] as num).toInt(),
  );
}