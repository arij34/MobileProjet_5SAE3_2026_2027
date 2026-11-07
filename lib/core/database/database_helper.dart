import 'package:flutter/foundation.dart';
import 'package:mygym/features/users/models/activity_log_table.dart';
import 'package:mygym/features/users/models/user_table.dart';
import 'package:mygym/features/challenges/models/challenge_table.dart';
import 'package:mygym/features/notifications/models/notification_table.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../features/gyms/models/gym_table.dart';
import '../../features/gyms/models/gym_equipment_table.dart';
import '../../features/gyms/models/gym_membership_table.dart';
import '../../features/gyms/models/gym_coach_tables.dart';
import '../../features/activities/models/activity_table.dart';
import '../../features/activities/models/activity_session_table.dart';
import '../../features/activities/models/session_reservation_table.dart';
import '../../features/nutrition/models/nutrition_tables.dart';
import '../../features/nutrition/repositories/food_repository.dart';

/// Accès unique à la base SQLite de MyGym (pattern singleton).
///
/// Utilisation dans un service :
///   final db = await DatabaseHelper.instance.database;
///
/// RÈGLE D'ÉQUIPE : pour ajouter une table, ajouter UNE ligne
/// dans _createAllTables (+ l'import en haut). Rien d'autre.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _dbName = 'mygym.db';
  static const int _dbVersion = 12;

  Future<Database>? _dbFuture;

  /// Ouvre la base une seule fois, même si plusieurs appels arrivent en même temps.
  Future<Database> get database => _dbFuture ??= _initDatabase();

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        // Active les clés étrangères (FOREIGN KEY) pour toute l'équipe.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) => _createAllTables(db),
      onUpgrade: _onUpgrade,
      // À chaque ouverture : crée les tables manquantes (ajoutées par un collègue).
      onOpen: (db) => _createAllTables(db),
    );
  }

  /// Toutes les tables du projet (IF NOT EXISTS obligatoire dans chaque createTable).
  /// Chaque collègue ajoute sa ligne ici.
  Future<void> _createAllTables(Database db) async {
    await UserTable.createTable(db); // Module Utilisateurs
    await ActivityLogTable.createTable(db); // Journal d'activité (après users)
    await GymTable.createTable(db); // Module Salles de sport
    await GymEquipmentTable.createTable(db); // Équipements (après gyms)
    await GymMembershipTable.createTable(db); // Adhésions (après users et gyms)
    await GymCoachTable.createTable(db); // Coachs de salle (après users et gyms)
    await GymCoachRequestTable.createTable(db); // Demandes salle <-> coach
    await ActivityTable.createTable(db); // Activités (après gyms)
    await ActivitySessionTable.createTable(db); // Séances (après activities et users)
    await SessionReservationTable.createTable(db); // Réservations (après sessions et users)
    await createNutritionTables(db); // Module Nutrition (6 tables, après users)
    await FoodRepository.seedIfEmpty(db); // Aliments de démonstration (si vide)
    await ChallengeTable.createAllTables(db); // Module Challenges
    await NotificationTable.createTable(db); // Notifications des challenges
    // --- Chaque collègue ajoute SA ligne ici (et son import en haut) ---
  }

  /// Ajoute une colonne seulement si elle n'existe pas déjà (migration rejouable).
  Future<void> _addColumnIfMissing(
      Database db, String table, String column, String type) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final existing = info.map((row) => row['name'] as String).toSet();
    if (!existing.contains(column)) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  /// Migrations : uniquement pour MODIFIER une table qui existe déjà.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await UserTable.upgradeToV2(db);
    if (oldVersion < 3) await UserTable.upgradeToV3(db);
    if (oldVersion < 4) await UserTable.upgradeToV4(db);
    if (oldVersion < 5) await UserTable.upgradeToV5(db);
    if (oldVersion < 6) {
      await GymTable.createTable(db);
      await GymEquipmentTable.createTable(db);
    }
    if (oldVersion < 7) {
      // v7 : photo_path sur les salles et les équipements.
      // Les bases créées en v6 n'ont pas cette colonne ; celles créées
      // depuis une version < 6 l'ont déjà : _addColumnIfMissing gère les deux cas.
      await GymTable.createTable(db);
      await GymEquipmentTable.createTable(db);
      await _addColumnIfMissing(
          db, GymTable.tableName, GymTable.colPhotoPath, 'TEXT');
      await _addColumnIfMissing(db, GymEquipmentTable.tableName,
          GymEquipmentTable.colPhotoPath, 'TEXT');
    }
    if (oldVersion < 8) {
      // v8 : adhésions aux salles (nouvelle table, rien à modifier).
      await GymMembershipTable.createTable(db);
    }
    if (oldVersion < 9) {
      // v9 : coachs de salle et demandes d'invitation / candidature.
      await GymCoachTable.createTable(db);
      await GymCoachRequestTable.createTable(db);
    }
    if (oldVersion < 10) {
      // v10 : module Activités (3 nouvelles tables, rien à modifier).
      await ActivityTable.createTable(db);
      await ActivitySessionTable.createTable(db);
      await SessionReservationTable.createTable(db);
    }
    if (oldVersion < 11) {
      // v11 : module Nutrition (6 nouvelles tables + aliments de démonstration).
      await createNutritionTables(db);
      await FoodRepository.seedIfEmpty(db);
    }
    if (oldVersion < 12) {
      // v12 : tables des challenges et notifications associées.
      await ChallengeTable.createAllTables(db);
      await NotificationTable.createTable(db);
    }
    // La table activity_log est créée par _createAllTables (onOpen).
    // Prochaine modification de table : if (oldVersion < 13) { ... } puis _dbVersion = 13
  }

  /// Outil de développement : supprime la base pour la recréer au prochain accès.
  Future<void> resetDatabase() async {
    final path = join(await getDatabasesPath(), _dbName);
    if (_dbFuture != null) {
      final db = await _dbFuture!;
      await db.close();
      _dbFuture = null;
    }
    await deleteDatabase(path);
  }

  /// Outil de développement : affiche les tables dans la console.
  Future<void> debugListTables() async {
    if (!kDebugMode) return;
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
    );
    debugPrint('Tables SQLite : ${rows.map((r) => r['name']).toList()}');
  }
}