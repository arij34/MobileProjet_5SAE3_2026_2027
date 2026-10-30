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
  static const String colStatus = 'status';
  static const String colCoachType = 'coach_type';
  static const String colCreatedAt = 'created_at';

  /// Rôles : administrateur, responsable de salle, nutritionniste,
  /// coach et adhérent. Statuts : actif, en attente, désactivé.
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colFirstName TEXT NOT NULL,
        $colLastName TEXT NOT NULL,
        $colEmail TEXT NOT NULL UNIQUE,
        $colPasswordHash TEXT NOT NULL,
        $colPhone TEXT NOT NULL,
        $colRole TEXT NOT NULL DEFAULT 'member'
          CHECK($colRole IN ('admin', 'gym_manager', 'nutritionist', 'coach', 'member')),
        $colStatus TEXT NOT NULL DEFAULT 'active'
          CHECK($colStatus IN ('active', 'pending', 'disabled')),
        $colCoachType TEXT
          CHECK($colCoachType IN ('gym_coach', 'free_coach')),
        $colCreatedAt TEXT NOT NULL
      )
    ''');
  }

  /// Migration v1 -> v2 : suppression de la colonne gym_id.
  /// On recrée la table, car DROP COLUMN n'est pas disponible
  /// sur les anciennes versions d'Android.
  static Future<void> upgradeToV2(Database db) async {
    // 1. On met l'ancienne table de côté
    await db.execute('ALTER TABLE $tableName RENAME TO ${tableName}_old');

    // 2. On crée la nouvelle table (schéma actuel, sans gym_id)
    await createTable(db);

    // 3. On copie les données (sans gym_id)
    await db.execute('''
      INSERT INTO $tableName
        ($colId, $colFirstName, $colLastName, $colEmail, $colPasswordHash,
         $colPhone, $colRole, $colStatus, $colCoachType, $colCreatedAt)
      SELECT
         $colId, $colFirstName, $colLastName, $colEmail, $colPasswordHash,
         $colPhone, $colRole, $colStatus, $colCoachType, $colCreatedAt
      FROM ${tableName}_old
    ''');

    // 4. On supprime l'ancienne table
    await db.execute('DROP TABLE ${tableName}_old');
  }
}