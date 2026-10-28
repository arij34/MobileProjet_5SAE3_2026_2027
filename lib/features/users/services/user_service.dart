import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/utils/password_hasher.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import '../models/user_table.dart';

/// Erreur métier (email déjà pris, mauvais mot de passe...) avec un message affichable.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

/// Toutes les opérations sur les utilisateurs (inscription, connexion, CRUD).
class UserService {
  UserService._();
  static final UserService instance = UserService._();

  // Compte administrateur créé automatiquement au premier lancement.
  // À CHANGER avant une vraie mise en production.
  static const String defaultAdminEmail = 'admin@mygym.com';
  static const String defaultAdminPassword = 'Admin@123';

  Future<Database> get _db => DatabaseHelper.instance.database;

  // ---------- Inscription / connexion ----------

  /// Inscription publique : le nouveau compte est toujours un adhérent.
  /// Seul l'administrateur peut ensuite changer le rôle (voir [setRole]).
  Future<User> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
  }) {
    return _createUser(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
      phone: phone,
      role: UserRole.member,
    );
  }

  Future<User> login(String email, String password) async {
    final user = await getByEmail(email);

    // Même message dans les deux cas pour ne pas révéler si l'email existe.
    if (user == null || !PasswordHasher.verify(password, user.passwordHash)) {
      throw AuthException('Email ou mot de passe incorrect.');
    }
    if (!user.isActive) {
      throw AuthException(
        'Ce compte est désactivé. Contactez un administrateur.',
      );
    }
    return user;
  }

  /// Réinitialisation du mot de passe (application locale, sans envoi d'email).
  Future<void> resetPassword(String email, String newPassword) async {
    final user = await getByEmail(email);
    if (user == null) {
      throw AuthException('Aucun compte ne correspond à cet email.');
    }
    final db = await _db;
    await db.update(
      UserTable.tableName,
      {UserTable.colPasswordHash: PasswordHasher.hash(newPassword)},
      where: '${UserTable.colId} = ?',
      whereArgs: [user.id],
    );
  }

  Future<void> changePassword(
    int userId,
    String oldPassword,
    String newPassword,
  ) async {
    final user = await getById(userId);
    if (user == null) throw AuthException('Utilisateur introuvable.');
    if (!PasswordHasher.verify(oldPassword, user.passwordHash)) {
      throw AuthException('L\'ancien mot de passe est incorrect.');
    }
    final db = await _db;
    await db.update(
      UserTable.tableName,
      {UserTable.colPasswordHash: PasswordHasher.hash(newPassword)},
      where: '${UserTable.colId} = ?',
      whereArgs: [userId],
    );
  }

  // ---------- Lecture ----------

  Future<User?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      UserTable.tableName,
      where: '${UserTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  Future<User?> getByEmail(String email) async {
    final db = await _db;
    final rows = await db.query(
      UserTable.tableName,
      where: '${UserTable.colEmail} = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  Future<bool> emailExists(String email) async {
    return (await getByEmail(email)) != null;
  }

  Future<List<User>> getAll({UserRole? role}) async {
    final db = await _db;
    final rows = await db.query(
      UserTable.tableName,
      where: role == null ? null : '${UserTable.colRole} = ?',
      whereArgs: role == null ? null : [role.value],
      orderBy: '${UserTable.colLastName} COLLATE NOCASE, '
          '${UserTable.colFirstName} COLLATE NOCASE',
    );
    return rows.map(User.fromMap).toList();
  }

  // ---------- Modification ----------

  /// Met à jour le profil (nom, prénom, téléphone). L'email et le rôle ne changent pas ici.
  Future<void> updateProfile(
    int userId, {
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    final db = await _db;
    await db.update(
      UserTable.tableName,
      {
        UserTable.colFirstName: firstName.trim(),
        UserTable.colLastName: lastName.trim(),
        UserTable.colPhone: (phone == null || phone.trim().isEmpty)
            ? null
            : phone.trim(),
      },
      where: '${UserTable.colId} = ?',
      whereArgs: [userId],
    );
  }

  /// Réservé à l'administrateur (le contrôle se fait dans l'interface).
  Future<void> setRole(int userId, UserRole role) async {
    final db = await _db;
    await db.update(
      UserTable.tableName,
      {UserTable.colRole: role.value},
      where: '${UserTable.colId} = ?',
      whereArgs: [userId],
    );
  }

  /// Active ou désactive un compte (réservé à l'administrateur).
  Future<void> setActive(int userId, bool isActive) async {
    final db = await _db;
    await db.update(
      UserTable.tableName,
      {UserTable.colIsActive: isActive ? 1 : 0},
      where: '${UserTable.colId} = ?',
      whereArgs: [userId],
    );
  }

  Future<void> delete(int userId) async {
    final db = await _db;
    await db.delete(
      UserTable.tableName,
      where: '${UserTable.colId} = ?',
      whereArgs: [userId],
    );
  }

  // ---------- Initialisation ----------

  /// Crée l'administrateur par défaut s'il n'y a aucun administrateur.
  /// Sans lui, personne ne pourrait attribuer les rôles.
  Future<void> ensureDefaultAdmin() async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM ${UserTable.tableName} '
      'WHERE ${UserTable.colRole} = ?',
      [UserRole.admin.value],
    );
    final adminCount = Sqflite.firstIntValue(result) ?? 0;
    if (adminCount > 0) return;

    await _createUser(
      firstName: 'Admin',
      lastName: 'MyGym',
      email: defaultAdminEmail,
      password: defaultAdminPassword,
      role: UserRole.admin,
    );
  }

  // ---------- Interne ----------

  Future<User> _createUser({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
    required UserRole role,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (await emailExists(cleanEmail)) {
      throw AuthException('Cet email est déjà utilisé.');
    }

    final user = User(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      email: cleanEmail,
      passwordHash: PasswordHasher.hash(password),
      phone: (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
      role: role,
      createdAt: DateTime.now(),
    );

    final db = await _db;
    final id = await db.insert(UserTable.tableName, user.toMap());
    return user.copyWith(id: id);
  }
}