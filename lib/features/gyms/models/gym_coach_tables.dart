import 'package:sqflite/sqflite.dart';

/// Table `gym_coaches` : coachs rattachés à une salle. Créée en version 9.
class GymCoachTable {
  static const String tableName = 'gym_coaches';

  static const String colId = 'id';
  static const String colGymId = 'gym_id'; // FK -> gyms
  static const String colCoachId = 'coach_id'; // FK -> users
  static const String colSpecialty = 'specialty';
  static const String colHourlyRate = 'hourly_rate'; // DT / séance
  static const String colAvailability = 'availability';
  static const String colStatus = 'status';
  static const String colJoinedAt = 'joined_at';

  /// Doit être créée APRÈS `users` et `gyms`. Un coach n'apparaît qu'une
  /// fois par salle (UNIQUE). Supprimer la salle ou le coach supprime le lien.
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colGymId INTEGER NOT NULL,
        $colCoachId INTEGER NOT NULL,
        $colSpecialty TEXT NOT NULL DEFAULT '',
        $colHourlyRate REAL NOT NULL DEFAULT 0 CHECK($colHourlyRate >= 0),
        $colAvailability TEXT NOT NULL DEFAULT '',
        $colStatus TEXT NOT NULL DEFAULT 'active'
          CHECK($colStatus IN ('active', 'suspended')),
        $colJoinedAt TEXT NOT NULL,
        UNIQUE ($colGymId, $colCoachId),
        FOREIGN KEY ($colGymId) REFERENCES gyms(id) ON DELETE CASCADE,
        FOREIGN KEY ($colCoachId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }
}

/// Table `gym_coach_requests` : invitations (salle -> coach) et
/// candidatures (coach -> salle). Créée en version 9.
class GymCoachRequestTable {
  static const String tableName = 'gym_coach_requests';

  static const String colId = 'id';
  static const String colGymId = 'gym_id';
  static const String colCoachId = 'coach_id';
  static const String colInitiatedBy = 'initiated_by'; // 'gym' ou 'coach'
  static const String colStatus = 'status';
  static const String colMessage = 'message';
  static const String colCreatedAt = 'created_at';
  static const String colRespondedAt = 'responded_at';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colGymId INTEGER NOT NULL,
        $colCoachId INTEGER NOT NULL,
        $colInitiatedBy TEXT NOT NULL
          CHECK($colInitiatedBy IN ('gym', 'coach')),
        $colStatus TEXT NOT NULL DEFAULT 'pending'
          CHECK($colStatus IN
            ('pending', 'accepted', 'rejected', 'cancelled')),
        $colMessage TEXT NOT NULL DEFAULT '',
        $colCreatedAt TEXT NOT NULL,
        $colRespondedAt TEXT,
        FOREIGN KEY ($colGymId) REFERENCES gyms(id) ON DELETE CASCADE,
        FOREIGN KEY ($colCoachId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }
}
