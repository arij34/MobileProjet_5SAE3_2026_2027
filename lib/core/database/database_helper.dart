import 'package:flutter/foundation.dart';
import 'package:mygym/features/users/models/activity_log_table.dart';
import 'package:mygym/features/users/models/user_table.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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
  static const int _dbVersion = 6;

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

    // --- Chaque collègue ajoute SA ligne ici (et son import en haut) ---
    // await GymTable.createTable(db);        // Module Salles de sport
    // await ChallengeTable.createTable(db);  // Module Challenges
    // await NutritionTable.createTable(db);  // Module Nutrition
    // await ActivityTable.createTable(db);   // Module Activités
  }

  /// Migrations : uniquement pour MODIFIER une table qui existe déjà.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await UserTable.upgradeToV2(db);
    if (oldVersion < 3) await UserTable.upgradeToV3(db);
    if (oldVersion < 4) await UserTable.upgradeToV4(db);
    if (oldVersion < 5) await UserTable.upgradeToV5(db);
    // La table activity_log est créée par _createAllTables (onOpen).
    // Prochaine modification de table : if (oldVersion < 7) { ... } puis _dbVersion = 7
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