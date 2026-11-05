import 'package:sqflite/sqflite.dart';

/// Définition de la table `gym_equipments` (équipements d'une salle).
class GymEquipmentTable {
  static const String tableName = 'gym_equipments';

  static const String colId = 'id';
  static const String colGymId = 'gym_id'; // FK -> gyms
  static const String colName = 'name';
  static const String colCategory = 'category';
  static const String colQuantity = 'quantity';
  static const String colState = 'state';
  static const String colCreatedAt = 'created_at';
  static const String colPhotoPath = 'photo_path';
  /// Créée en version 6. Supprimer une salle supprime ses équipements (CASCADE).
  /// Doit être créée APRÈS la table `gyms`.
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colGymId INTEGER NOT NULL,
        $colName TEXT NOT NULL,
        $colCategory TEXT NOT NULL DEFAULT 'other'
          CHECK($colCategory IN
            ('cardio', 'strength', 'group_classes', 'functional', 'other')),
        $colQuantity INTEGER NOT NULL DEFAULT 1
          CHECK($colQuantity > 0),
        $colState TEXT NOT NULL DEFAULT 'good'
          CHECK($colState IN ('good', 'needs_repair', 'out_of_order')),
          $colPhotoPath TEXT,
        $colCreatedAt TEXT NOT NULL,
        FOREIGN KEY ($colGymId) REFERENCES gyms(id) ON DELETE CASCADE
      
      )
    ''');
  }
}
