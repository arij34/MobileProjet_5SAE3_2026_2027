import 'user_gender.dart';
import 'user_goal.dart';
import 'user_role.dart';
import 'user_status.dart';
import 'user_table.dart';

class User {
  final int? id;
  final String firstName;
  final String lastName;
  final String email;
  final String passwordHash;
  final String phone;
  final UserRole role;
  final UserStatus status;
  final CoachType? coachType; // seulement si role == coach
  final UserGender? gender;
  final DateTime createdAt;

  // Profil enrichi (facultatif)
  final String? photoUrl;
  final DateTime? birthDate;
  final double? heightCm;
  final double? weightKg;
  final UserGoal? goal;

  // Points d'expérience cumulés
  final int xp;

  // Photo du justificatif (coach, nutritionniste, responsable de salle)
  final String? proofPath;

  const User({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.passwordHash,
    required this.phone,
    this.role = UserRole.member,
    this.status = UserStatus.active,
    this.coachType,
    this.gender,
    required this.createdAt,
    this.photoUrl,
    this.birthDate,
    this.heightCm,
    this.weightKg,
    this.goal,
    this.xp = 0,
    this.proofPath,
  });

  String get fullName => '$firstName $lastName';

  bool get isActive => status == UserStatus.active;
  bool get isPending => status == UserStatus.pending;
  bool get hasProof => proofPath != null && proofPath!.isNotEmpty;

  /// Âge calculé à partir de la date de naissance (null si inconnue).
  int? get age {
    final b = birthDate;
    if (b == null) return null;
    final now = DateTime.now();
    var years = now.year - b.year;
    final birthdayPassed =
        now.month > b.month || (now.month == b.month && now.day >= b.day);
    if (!birthdayPassed) years--;
    return years;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) UserTable.colId: id,
      UserTable.colFirstName: firstName,
      UserTable.colLastName: lastName,
      UserTable.colEmail: email,
      UserTable.colPasswordHash: passwordHash,
      UserTable.colPhone: phone,
      UserTable.colRole: role.value,
      UserTable.colStatus: status.value,
      UserTable.colCoachType: coachType?.value,
      UserTable.colGender: gender?.value,
      UserTable.colCreatedAt: createdAt.toIso8601String(),
      UserTable.colPhotoUrl: photoUrl,
      UserTable.colBirthDate: birthDate?.toIso8601String(),
      UserTable.colHeightCm: heightCm,
      UserTable.colWeightKg: weightKg,
      UserTable.colGoal: goal?.value,
      UserTable.colXp: xp,
      UserTable.colProofPath: proofPath,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    final birth = map[UserTable.colBirthDate] as String?;
    return User(
      id: map[UserTable.colId] as int?,
      firstName: map[UserTable.colFirstName] as String,
      lastName: map[UserTable.colLastName] as String,
      email: map[UserTable.colEmail] as String,
      passwordHash: map[UserTable.colPasswordHash] as String,
      phone: map[UserTable.colPhone] as String,
      role: UserRole.fromValue(map[UserTable.colRole] as String?),
      status: UserStatus.fromValue(map[UserTable.colStatus] as String?),
      coachType: CoachType.fromValue(map[UserTable.colCoachType] as String?),
      gender: UserGender.fromValue(map[UserTable.colGender] as String?),
      createdAt: DateTime.parse(map[UserTable.colCreatedAt] as String),
      photoUrl: map[UserTable.colPhotoUrl] as String?,
      birthDate: birth == null ? null : DateTime.tryParse(birth),
      heightCm: (map[UserTable.colHeightCm] as num?)?.toDouble(),
      weightKg: (map[UserTable.colWeightKg] as num?)?.toDouble(),
      goal: UserGoal.fromValue(map[UserTable.colGoal] as String?),
      xp: (map[UserTable.colXp] as int?) ?? 0,
      proofPath: map[UserTable.colProofPath] as String?,
    );
  }

  User copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? email,
    String? passwordHash,
    String? phone,
    UserRole? role,
    UserStatus? status,
    CoachType? coachType,
    UserGender? gender,
    DateTime? createdAt,
    String? photoUrl,
    DateTime? birthDate,
    double? heightCm,
    double? weightKg,
    UserGoal? goal,
    int? xp,
    String? proofPath,
  }) {
    return User(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      status: status ?? this.status,
      coachType: coachType ?? this.coachType,
      gender: gender ?? this.gender,
      createdAt: createdAt ?? this.createdAt,
      photoUrl: photoUrl ?? this.photoUrl,
      birthDate: birthDate ?? this.birthDate,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      goal: goal ?? this.goal,
      xp: xp ?? this.xp,
      proofPath: proofPath ?? this.proofPath,
    );
  }
}