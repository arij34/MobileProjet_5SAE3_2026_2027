import 'package:sqflite/sqflite.dart';

/// Définition de la table `gyms` (module Salles de sport).
class GymTable {
  static const String tableName = 'gyms';

  static const String colId = 'id';
  static const String colOwnerId = 'owner_id'; // responsable (FK -> users)
  static const String colName = 'name';
  static const String colDescription = 'description';
  static const String colAddress = 'address';
  static const String colCity = 'city';
  static const String colLatitude = 'latitude'; // rempli par le géocodage
  static const String colLongitude = 'longitude';
  static const String colPhone = 'phone';
  static const String colOpeningHours = 'opening_hours';
  static const String colCapacity = 'capacity';
  static const String colPriceMonthly = 'price_monthly';
  static const String colStatus = 'status';
  static const String colCreatedAt = 'created_at';
  static const String colPhotoPath = 'photo_path';

  /// Créée en version 6. IF NOT EXISTS : sans danger si rejouée.
  /// Si le responsable est supprimé, ses salles le sont aussi (CASCADE).
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colOwnerId INTEGER NOT NULL,
        $colName TEXT NOT NULL,
        $colDescription TEXT NOT NULL DEFAULT '',
        $colAddress TEXT NOT NULL,
        $colCity TEXT NOT NULL,
        $colLatitude REAL,
        $colLongitude REAL,
        $colPhone TEXT NOT NULL DEFAULT '',
        $colOpeningHours TEXT NOT NULL DEFAULT '',
        $colCapacity INTEGER NOT NULL DEFAULT 0
          CHECK($colCapacity >= 0),
        $colPriceMonthly REAL NOT NULL DEFAULT 0
          CHECK($colPriceMonthly >= 0),
        $colStatus TEXT NOT NULL DEFAULT 'open'
          CHECK($colStatus IN ('open', 'closed', 'pending')),
          $colPhotoPath TEXT,
        $colCreatedAt TEXT NOT NULL,
        FOREIGN KEY ($colOwnerId) REFERENCES users(id) ON DELETE CASCADE
        
      )
    ''');
  }
}
