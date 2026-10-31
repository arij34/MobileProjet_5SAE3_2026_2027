import 'package:flutter/foundation.dart';
import 'package:mygym/features/users/models/activity_log_table.dart';
import 'package:mygym/features/users/models/user_table.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Accès unique à la base SQLite de MyGym (pattern singleton).
///
/// Utilisation dans un service :
///   final db = await DatabaseHelper.instance.database;
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _dbName = 'mygym.db';
  static const int _dbVersion = 3; // 3 : profil enrichi, XP, journal d'activités

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
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Crée toutes les tables au premier lancement de l'application.
  Future<void> _onCreate(Database db, int version) async {
    await UserTable.createTable(db); // Module Utilisateurs
    await ActivityLogTable.createTable(db); // Journal d'activités (utilisateurs)

    // --- Chaque collègue ajoute la création de sa table ici ---
    // await GymTable.createTable(db);        // Module Salles de sport
    // await ChallengeTable.createTable(db);  // Module Challenges
    // await NutritionTable.createTable(db);  // Module Nutrition
    // await ActivityTable.createTable(db);   // Module Activités
  }

  /// Migrations pour les bases déjà installées.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await UserTable.upgradeToV2(db); // v2 : suppression de users.gym_id
    }
    if (oldVersion < 3) {
      await UserTable.upgradeToV3(db); // v3 : profil enrichi + XP
      await ActivityLogTable.createTable(db); // v3 : journal d'activités
    }
    // Prochaines migrations (collègues) : version 4 et suivantes
    // if (oldVersion < 4) { await GymTable.createTable(db); }
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