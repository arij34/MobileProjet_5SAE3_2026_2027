import 'user_goal.dart';
import 'user_role.dart';
import 'user_status.dart';
import 'user_table.dart';
import 'user_gender.dart';

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
  final DateTime createdAt;

  // Profil enrichi (facultatif)
  final String? photoUrl;
  final DateTime? birthDate;
  final double? heightCm;
  final double? weightKg;
  final UserGoal? goal;
  final UserGender? gender;

  // Points d'expérience cumulés
  final int xp;

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
    required this.createdAt,
    this.photoUrl,
    this.birthDate,
    this.heightCm,
    this.weightKg,
    this.goal,
    this.xp = 0,
    this.gender,
  });

  String get fullName => '$firstName $lastName';

  bool get isActive => status == UserStatus.active;
  bool get isPending => status == UserStatus.pending;

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
      UserTable.colCreatedAt: createdAt.toIso8601String(),
      UserTable.colPhotoUrl: photoUrl,
      UserTable.colBirthDate: birthDate?.toIso8601String(),
      UserTable.colHeightCm: heightCm,
      UserTable.colWeightKg: weightKg,
      UserTable.colGoal: goal?.value,
      UserTable.colXp: xp,
      UserTable.colGender: gender?.value,
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
      createdAt: DateTime.parse(map[UserTable.colCreatedAt] as String),
      photoUrl: map[UserTable.colPhotoUrl] as String?,
      birthDate: birth == null ? null : DateTime.tryParse(birth),
      heightCm: (map[UserTable.colHeightCm] as num?)?.toDouble(),
      weightKg: (map[UserTable.colWeightKg] as num?)?.toDouble(),
      goal: UserGoal.fromValue(map[UserTable.colGoal] as String?),
      xp: (map[UserTable.colXp] as int?) ?? 0,
      gender: UserGender.fromValue(map[UserTable.colGender] as String?),
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
    DateTime? createdAt,
    String? photoUrl,
    DateTime? birthDate,
    double? heightCm,
    double? weightKg,
    UserGoal? goal,
    int? xp,
    UserGender? gender,
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
      createdAt: createdAt ?? this.createdAt,
      photoUrl: photoUrl ?? this.photoUrl,
      birthDate: birthDate ?? this.birthDate,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      goal: goal ?? this.goal,
      xp: xp ?? this.xp,
      gender: gender ?? this.gender,
    );
  }
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
}