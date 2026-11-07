import 'package:sqflite/sqflite.dart';

/// Définition de la table `challenges` (module Challenges).
class ChallengeTable {
  static const String tableName = 'challenges';

  static const String colId = 'id';
  static const String colTitle = 'title';
  static const String colDescription = 'description';
  static const String colDifficulty = 'difficulty';
  static const String colXpReward = 'xp_reward';
  static const String colStartDate = 'start_date';
  static const String colEndDate = 'end_date';
  static const String colStatus = 'status';
  static const String colImagePath = 'image_path';
  static const String colCreatedBy = 'created_by';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';
  static const String colRejectionReason = 'rejection_reason';
  static const String colReviewedBy = 'reviewed_by';
  static const String colReviewedAt = 'reviewed_at';

  // Alias renvoyé par les requêtes avec jointure : ce n'est pas une colonne.
  static const String colCreatorName = 'creator_name';
  static const String colReviewerName = 'reviewer_name';

  /// Crée les quatre tables du module (et leurs index) si elles n'existent pas.
  /// Appelée à la création de la base, à la migration et à chaque ouverture.
  static Future<void> createAllTables(Database db) async {
    await createTable(db);
    await ChallengeTaskTable.createTable(db);
    await ChallengeParticipantTable.createTable(db);
    await ChallengeTaskProgressTable.createTable(db);
    await ChallengeTaskLogTable.createTable(db);
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colTitle TEXT NOT NULL,
        $colDescription TEXT,
        $colDifficulty TEXT NOT NULL
          CHECK($colDifficulty IN ('easy', 'medium', 'hard')),
        $colXpReward INTEGER NOT NULL,
        $colStartDate TEXT NOT NULL,
        $colEndDate TEXT NOT NULL,
        $colStatus TEXT NOT NULL
          CHECK($colStatus IN ('draft', 'pending', 'rejected', 'active', 'cancelled')),
        $colImagePath TEXT,
        $colCreatedBy INTEGER NOT NULL,
        $colCreatedAt TEXT NOT NULL,
        $colUpdatedAt TEXT NOT NULL,
        $colRejectionReason TEXT,
        $colReviewedBy INTEGER,
        $colReviewedAt TEXT,
        FOREIGN KEY ($colCreatedBy) REFERENCES users(id),
        FOREIGN KEY ($colReviewedBy) REFERENCES users(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_${tableName}_$colCreatedBy '
      'ON $tableName($colCreatedBy)',
    );
  }

  /// La contrainte CHECK de v7 impose de recréer les tables liées.
  static Future<void> upgradeToV8(Database db) async {
    final tables = [
      tableName,
      ChallengeTaskTable.tableName,
      ChallengeParticipantTable.tableName,
      ChallengeTaskProgressTable.tableName,
    ];
    final sequences = await db.query(
      'sqlite_sequence',
      where: 'name IN (?, ?, ?, ?)',
      whereArgs: tables,
    );
    for (final table in tables) {
      await db.execute(
        'CREATE TEMP TABLE backup_$table AS SELECT * FROM $table',
      );
    }
    for (final table in tables.reversed) {
      await db.execute('DROP TABLE $table');
    }
    await createAllTables(db);
    const oldColumns =
        '$colId, $colTitle, $colDescription, $colDifficulty, '
        '$colXpReward, $colStartDate, $colEndDate, $colStatus, $colImagePath, '
        '$colCreatedBy, $colCreatedAt, $colUpdatedAt';
    await db.execute(
      'INSERT INTO $tableName ($oldColumns) SELECT $oldColumns FROM backup_$tableName',
    );
    const taskColumns =
        'id, challenge_id, title, description, type, unit, '
        'target_value, xp_reward, order_index';
    await db.execute(
      'INSERT INTO ${ChallengeTaskTable.tableName} ($taskColumns) '
      'SELECT $taskColumns FROM backup_${ChallengeTaskTable.tableName}',
    );
    for (final table in tables.skip(2)) {
      await db.execute('INSERT INTO $table SELECT * FROM backup_$table');
    }
    for (final table in tables.reversed) {
      await db.execute('DROP TABLE backup_$table');
    }
    for (final sequence in sequences) {
      await db.delete(
        'sqlite_sequence',
        where: 'name = ?',
        whereArgs: [sequence['name']],
      );
      await db.insert('sqlite_sequence', sequence);
    }
    for (final table in tables) {
      final violations = await db.rawQuery('PRAGMA foreign_key_check($table)');
      if (violations.isNotEmpty) {
        throw StateError(
          'Migration Challenges : clés étrangères invalides : $violations',
        );
      }
    }
  }
}

class ChallengeTaskLogTable {
  static const tableName = 'challenge_task_logs';
  static const colId = 'id';
  static const colParticipantId = 'participant_id';
  static const colTaskId = 'task_id';
  static const colLogDate = 'log_date';
  static const colAmount = 'amount';
  static const colCreatedAt = 'created_at';
  static const colIsEstimated = 'is_estimated';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colParticipantId INTEGER NOT NULL REFERENCES challenge_participants(id) ON DELETE CASCADE,
        $colTaskId INTEGER NOT NULL REFERENCES challenge_tasks(id) ON DELETE CASCADE,
        $colLogDate TEXT NOT NULL,
        $colAmount REAL NOT NULL,
        $colCreatedAt TEXT NOT NULL,
        $colIsEstimated INTEGER NOT NULL DEFAULT 0,
        UNIQUE ($colParticipantId, $colTaskId, $colLogDate)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_challenge_task_logs_participant ON $tableName($colParticipantId)',
    );
  }

  static Future<void> migrateLegacyProgress(Database db) async {
    await db.execute('''
      INSERT OR IGNORE INTO $tableName
        ($colParticipantId, $colTaskId, $colLogDate, $colAmount, $colCreatedAt, $colIsEstimated)
      SELECT g.participant_id, g.task_id,
        CASE
          WHEN substr(COALESCE(g.completed_at, p.joined_at), 1, 10) < substr(c.start_date, 1, 10) THEN substr(c.start_date, 1, 10)
          WHEN substr(COALESCE(g.completed_at, p.joined_at), 1, 10) > substr(c.end_date, 1, 10) THEN substr(c.end_date, 1, 10)
          ELSE substr(COALESCE(g.completed_at, p.joined_at), 1, 10)
        END,
        g.progress, COALESCE(g.completed_at, p.joined_at), 1
      FROM challenge_task_progress g
      JOIN challenge_participants p ON p.id = g.participant_id
      JOIN challenge_tasks t ON t.id = g.task_id AND t.challenge_id = p.challenge_id
      JOIN challenges c ON c.id = p.challenge_id
      WHERE g.progress > 0
    ''');
  }
}

/// Tâches d'un challenge (liste simple, à cocher avant la date de fin).
class ChallengeTaskTable {
  static const String tableName = 'challenge_tasks';

  static const String colId = 'id';
  static const String colChallengeId = 'challenge_id';
  static const String colTitle = 'title';
  static const String colDescription = 'description';
  static const String colType = 'type';
  static const String colUnit = 'unit';
  static const String colTargetValue = 'target_value';
  static const String colXpReward = 'xp_reward';
  static const String colOrderIndex = 'order_index';
  static const String colScheduledDates = 'scheduled_dates';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colChallengeId INTEGER NOT NULL,
        $colTitle TEXT NOT NULL,
        $colDescription TEXT,
        $colType TEXT NOT NULL,
        $colUnit TEXT NOT NULL,
        $colTargetValue REAL NOT NULL CHECK($colTargetValue > 0),
        $colXpReward INTEGER NOT NULL DEFAULT 0,
        $colOrderIndex INTEGER NOT NULL,
        $colScheduledDates TEXT,
        FOREIGN KEY ($colChallengeId)
          REFERENCES ${ChallengeTable.tableName}(${ChallengeTable.colId})
          ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_${tableName}_$colChallengeId '
      'ON $tableName($colChallengeId)',
    );
  }

  static Future<void> upgradeToV11(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    if (!columns.any((column) => column['name'] == colScheduledDates)) {
      await db.execute(
        'ALTER TABLE $tableName ADD COLUMN $colScheduledDates TEXT',
      );
    }
  }
}

/// Inscriptions des membres aux challenges (pas encore utilisée).
class ChallengeParticipantTable {
  static const String tableName = 'challenge_participants';

  static const String colId = 'id';
  static const String colChallengeId = 'challenge_id';
  static const String colUserId = 'user_id';
  static const String colStatus = 'status';
  static const String colJoinedAt = 'joined_at';
  static const String colCompletedAt = 'completed_at';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colChallengeId INTEGER NOT NULL,
        $colUserId INTEGER NOT NULL,
        $colStatus TEXT NOT NULL DEFAULT 'joined'
          CHECK($colStatus IN ('joined', 'completed', 'abandoned')),
        $colJoinedAt TEXT NOT NULL,
        $colCompletedAt TEXT,
        UNIQUE ($colChallengeId, $colUserId),
        FOREIGN KEY ($colChallengeId)
          REFERENCES ${ChallengeTable.tableName}(${ChallengeTable.colId})
          ON DELETE CASCADE,
        FOREIGN KEY ($colUserId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }
}

/// Avancement d'un participant sur chaque tâche (pas encore utilisé).
class ChallengeTaskProgressTable {
  static const String tableName = 'challenge_task_progress';

  static const String colId = 'id';
  static const String colParticipantId = 'participant_id';
  static const String colTaskId = 'task_id';
  static const String colProgress = 'progress';
  static const String colCompleted = 'completed';
  static const String colCompletedAt = 'completed_at';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colParticipantId INTEGER NOT NULL,
        $colTaskId INTEGER NOT NULL,
        $colProgress REAL NOT NULL DEFAULT 0,
        $colCompleted INTEGER NOT NULL DEFAULT 0,
        $colCompletedAt TEXT,
        UNIQUE ($colParticipantId, $colTaskId),
        FOREIGN KEY ($colParticipantId)
          REFERENCES ${ChallengeParticipantTable.tableName}(${ChallengeParticipantTable.colId})
          ON DELETE CASCADE,
        FOREIGN KEY ($colTaskId)
          REFERENCES ${ChallengeTaskTable.tableName}(${ChallengeTaskTable.colId})
          ON DELETE CASCADE
      )
    ''');
  }
}
