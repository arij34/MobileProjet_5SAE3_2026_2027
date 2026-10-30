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
  final DateTime createdAt;

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
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
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
    );
  }
}