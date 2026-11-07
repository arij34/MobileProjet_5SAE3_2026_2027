import 'package:sqflite/sqflite.dart';

import '../../challenges/models/challenge_table.dart';
import '../../users/models/user_table.dart';

class NotificationTable {
  static const tableName = 'notifications';
  static const colId = 'id';
  static const colUserId = 'user_id';
  static const colType = 'type';
  static const colTitle = 'title';
  static const colBody = 'body';
  static const colChallengeId = 'challenge_id';
  static const colIsRead = 'is_read';
  static const colCreatedAt = 'created_at';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colUserId INTEGER NOT NULL,
        $colType TEXT NOT NULL,
        $colTitle TEXT NOT NULL,
        $colBody TEXT NOT NULL,
        $colChallengeId INTEGER,
        $colIsRead INTEGER NOT NULL DEFAULT 0,
        $colCreatedAt TEXT NOT NULL,
        FOREIGN KEY ($colUserId) REFERENCES ${UserTable.tableName}(${UserTable.colId}) ON DELETE CASCADE,
        FOREIGN KEY ($colChallengeId) REFERENCES ${ChallengeTable.tableName}(${ChallengeTable.colId}) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notifications_user_read '
      'ON $tableName($colUserId, $colIsRead)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_notifications_user_created '
      'ON $tableName($colUserId, $colCreatedAt)',
    );
  }
}
