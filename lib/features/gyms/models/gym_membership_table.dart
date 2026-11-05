import 'package:sqflite/sqflite.dart';

/// Définition de la table `gym_memberships` (demandes et adhésions aux salles).
class GymMembershipTable {
  static const String tableName = 'gym_memberships';

  static const String colId = 'id';
  static const String colUserId = 'user_id'; // adhérent (FK -> users)
  static const String colGymId = 'gym_id'; // salle (FK -> gyms)
  static const String colMonths = 'months'; // durée choisie : 1, 3 ou 12
  static const String colPriceTotal = 'price_total'; // prix total en DT
  static const String colStatus = 'status';
  static const String colQrToken = 'qr_token'; // contenu du QR (après acceptation)
  static const String colStartDate = 'start_date';
  static const String colEndDate = 'end_date';
  static const String colCreatedAt = 'created_at';

  /// Créée en version 8. IF NOT EXISTS : sans danger si rejouée.
  /// Doit être créée APRÈS les tables `users` et `gyms`.
  /// Si l'adhérent ou la salle est supprimé, ses adhésions le sont aussi (CASCADE).
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colUserId INTEGER NOT NULL,
        $colGymId INTEGER NOT NULL,
        $colMonths INTEGER NOT NULL CHECK($colMonths > 0),
        $colPriceTotal REAL NOT NULL DEFAULT 0 CHECK($colPriceTotal >= 0),
        $colStatus TEXT NOT NULL DEFAULT 'pending'
          CHECK($colStatus IN
            ('pending', 'active', 'rejected', 'expired', 'cancelled')),
        $colQrToken TEXT UNIQUE,
        $colStartDate TEXT,
        $colEndDate TEXT,
        $colCreatedAt TEXT NOT NULL,
        FOREIGN KEY ($colUserId) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY ($colGymId) REFERENCES gyms(id) ON DELETE CASCADE
      )
    ''');
  }
}
