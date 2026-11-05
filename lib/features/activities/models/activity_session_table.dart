import 'package:sqflite/sqflite.dart';

/// Définition de la table `activity_sessions` (séances planifiées d'une activité).
///
/// Une séance appartient à une activité (CASCADE). Un coach peut y être associé ;
/// si son compte est supprimé, la séance reste mais le coach passe à NULL.
/// Créée en version 10 de la base.
class ActivitySessionTable {
  static const String tableName = 'activity_sessions';

  static const String colId = 'id';
  static const String colActivityId = 'activity_id'; // FK -> activities
  static const String colCoachId = 'coach_id'; // FK -> users (facultatif)
  static const String colStartAt = 'start_at'; // date + heure, ISO 8601
  static const String colDurationMin = 'duration_min'; // durée réelle de la séance
  static const String colCapacityMax = 'capacity_max'; // nombre de places
  static const String colCreatedAt = 'created_at';

  /// IF NOT EXISTS : sans danger si rejouée.
  /// Doit être créée APRÈS `activities` et `users`.
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colActivityId INTEGER NOT NULL,
        $colCoachId INTEGER,
        $colStartAt TEXT NOT NULL,
        $colDurationMin INTEGER NOT NULL DEFAULT 60
          CHECK($colDurationMin > 0),
        $colCapacityMax INTEGER NOT NULL DEFAULT 1
          CHECK($colCapacityMax > 0),
        $colCreatedAt TEXT NOT NULL,
        FOREIGN KEY ($colActivityId) REFERENCES activities(id) ON DELETE CASCADE,
        FOREIGN KEY ($colCoachId) REFERENCES users(id) ON DELETE SET NULL
      )
    ''');
  }
}
