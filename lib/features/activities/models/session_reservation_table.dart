import 'package:sqflite/sqflite.dart';

/// Définition de la table `session_reservations` (réservations des adhérents).
///
/// Une réservation lie un adhérent (user) à une séance (session), les deux en
/// CASCADE. Un même adhérent peut avoir plusieurs lignes dans le temps (ex. une
/// annulée puis une nouvelle) : l'unicité d'une réservation ACTIVE est garantie
/// par le service, pas par une contrainte, afin de conserver l'historique.
/// Créée en version 10 de la base.
class SessionReservationTable {
  static const String tableName = 'session_reservations';

  static const String colId = 'id';
  static const String colSessionId = 'session_id'; // FK -> activity_sessions
  static const String colUserId = 'user_id'; // FK -> users (adhérent)
  static const String colStatus = 'status'; // ReservationStatus.value
  static const String colGoogleEventId = 'google_event_id'; // anti-doublon Agenda
  static const String colCreatedAt = 'created_at'; // sert à ordonner la file d'attente
  static const String colUpdatedAt = 'updated_at';

  /// IF NOT EXISTS : sans danger si rejouée.
  /// Doit être créée APRÈS `activity_sessions` et `users`.
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colSessionId INTEGER NOT NULL,
        $colUserId INTEGER NOT NULL,
        $colStatus TEXT NOT NULL DEFAULT 'confirmed'
          CHECK($colStatus IN ('confirmed', 'waitlisted', 'cancelled')),
        $colGoogleEventId TEXT,
        $colCreatedAt TEXT NOT NULL,
        $colUpdatedAt TEXT NOT NULL,
        FOREIGN KEY ($colSessionId) REFERENCES activity_sessions(id) ON DELETE CASCADE,
        FOREIGN KEY ($colUserId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }
}
