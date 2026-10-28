import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/users/models/user_table.dart';

/// Accès unique à la base SQLite de MyGym (pattern singleton).
///
/// Utilisation dans un service :
///   final db = await DatabaseHelper.instance.database;
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const String _dbName = 'mygym.db';
  static const int _dbVersion = 1;

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
    );
  }

  /// Crée toutes les tables au premier lancement de l'application.
  Future<void> _onCreate(Database db, int version) async {
    await UserTable.createTable(db); // Module Utilisateurs

    // --- Chaque collègue ajoute la création de sa table ici ---
    // await GymTable.createTable(db);        // Module Salles de sport
    // await ChallengeTable.createTable(db);  // Module Challenges
    // await NutritionTable.createTable(db);  // Module Nutrition
    // await ActivityTable.createTable(db);   // Module Activités
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