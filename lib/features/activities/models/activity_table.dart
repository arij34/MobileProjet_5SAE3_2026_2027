import 'package:sqflite/sqflite.dart';

/// Définition de la table `activities` (module Gestion des activités sportives).
///
/// Une activité appartient à une salle (gym). Si la salle est supprimée, ses
/// activités le sont aussi (CASCADE). Créée en version 10 de la base.
class ActivityTable {
  static const String tableName = 'activities';

  static const String colId = 'id';
  static const String colGymId = 'gym_id'; // salle (FK -> gyms)
  static const String colName = 'name';
  static const String colDescription = 'description';
  static const String colCategory = 'category'; // ActivityCategory.value
  static const String colDurationMin = 'duration_min'; // durée en minutes
  static const String colLevel = 'level'; // ActivityLevel.value (facultatif)
  static const String colObjective = 'objective'; // objectif sportif (facultatif)
  static const String colCreatedAt = 'created_at';

  /// IF NOT EXISTS : sans danger si rejouée.
  /// Doit être créée APRÈS la table `gyms`.
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colGymId INTEGER NOT NULL,
        $colName TEXT NOT NULL,
        $colDescription TEXT NOT NULL DEFAULT '',
        $colCategory TEXT NOT NULL DEFAULT 'other',
        $colDurationMin INTEGER NOT NULL DEFAULT 60
          CHECK($colDurationMin > 0),
        $colLevel TEXT NOT NULL DEFAULT 'beginner',
        $colObjective TEXT NOT NULL DEFAULT '',
        $colCreatedAt TEXT NOT NULL,
        FOREIGN KEY ($colGymId) REFERENCES gyms(id) ON DELETE CASCADE
      )
    ''');
  }
}
