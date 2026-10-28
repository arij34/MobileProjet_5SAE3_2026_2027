import 'package:sqflite/sqflite.dart';

/// Définition de la table `users` (module Utilisateurs).
class UserTable {
  static const String tableName = 'users';

  static const String colId = 'id';
  static const String colFirstName = 'first_name';
  static const String colLastName = 'last_name';
  static const String colEmail = 'email';
  static const String colPasswordHash = 'password_hash';
  static const String colPhone = 'phone';
  static const String colRole = 'role';
  static const String colIsActive = 'is_active';
  static const String colCreatedAt = 'created_at';

  /// Rôles autorisés : administrateur, responsable de salle,
  /// nutritionniste et adhérent (cahier des charges, section 2.1).
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colFirstName TEXT NOT NULL,
        $colLastName TEXT NOT NULL,
        $colEmail TEXT NOT NULL UNIQUE,
        $colPasswordHash TEXT NOT NULL,
        $colPhone TEXT,
        $colRole TEXT NOT NULL DEFAULT 'member'
          CHECK($colRole IN ('admin', 'gym_manager', 'nutritionist', 'member')),
        $colIsActive INTEGER NOT NULL DEFAULT 1,
        $colCreatedAt TEXT NOT NULL
      )
    ''');
  }
}