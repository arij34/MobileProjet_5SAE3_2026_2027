import 'user_role.dart';
import 'user_table.dart';

class User {
  final int? id;
  final String firstName;
  final String lastName;
  final String email;
  final String passwordHash;
  final String? phone;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;

  const User({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.passwordHash,
    this.phone,
    this.role = UserRole.member,
    this.isActive = true,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) UserTable.colId: id,
      UserTable.colFirstName: firstName,
      UserTable.colLastName: lastName,
      UserTable.colEmail: email,
      UserTable.colPasswordHash: passwordHash,
      UserTable.colPhone: phone,
      UserTable.colRole: role.value,
      UserTable.colIsActive: isActive ? 1 : 0,
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
      phone: map[UserTable.colPhone] as String?,
      role: UserRole.fromValue(map[UserTable.colRole] as String?),
      isActive: (map[UserTable.colIsActive] as int) == 1,
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
    bool? isActive,
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
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}