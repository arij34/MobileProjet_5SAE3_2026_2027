import 'package:sqflite/sqflite.dart';

/// Journal des activités d'un utilisateur (historique + points d'expérience).
class ActivityLogTable {
  static const String tableName = 'activity_log';

  static const String colId = 'id';
  static const String colUserId = 'user_id';
  static const String colType = 'type';
  static const String colDescription = 'description';
  static const String colXp = 'xp';
  static const String colCreatedAt = 'created_at';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colUserId INTEGER NOT NULL,
        $colType TEXT NOT NULL,
        $colDescription TEXT NOT NULL,
        $colXp INTEGER NOT NULL DEFAULT 0,
        $colCreatedAt TEXT NOT NULL,
        FOREIGN KEY ($colUserId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }
}