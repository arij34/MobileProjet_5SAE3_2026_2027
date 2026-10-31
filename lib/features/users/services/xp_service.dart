import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../models/activity_log.dart';
import '../models/activity_log_table.dart';
import '../models/user_table.dart';

/// Gère les points d'expérience (XP) et le journal d'activités.
/// Le module Utilisateurs possède l'XP ; les autres modules l'appellent.
class XpService {
  XpService._();
  static final XpService instance = XpService._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Ajoute des XP à un utilisateur ET écrit une ligne dans l'historique.
  /// Les deux actions sont faites ensemble (transaction) : si l'une échoue,
  /// l'autre est annulée.
  Future<void> addXp({
    required int userId,
    required int amount,
    required String type,
    required String description,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert(ActivityLogTable.tableName, {
        ActivityLogTable.colUserId: userId,
        ActivityLogTable.colType: type,
        ActivityLogTable.colDescription: description,
        ActivityLogTable.colXp: amount,
        ActivityLogTable.colCreatedAt: DateTime.now().toIso8601String(),
      });
      await txn.rawUpdate(
        'UPDATE ${UserTable.tableName} '
        'SET ${UserTable.colXp} = ${UserTable.colXp} + ? '
        'WHERE ${UserTable.colId} = ?',
        [amount, userId],
      );
    });
  }

  /// Donne les XP une seule fois dans la vie du compte pour ce [type].
  /// Retourne les XP gagnés (0 si déjà donnés).
  Future<int> awardOnce(
    int userId,
    String type,
    int amount,
    String description,
  ) async {
    final db = await _db;
    final rows = await db.query(
      ActivityLogTable.tableName,
      where: '${ActivityLogTable.colUserId} = ? AND '
          '${ActivityLogTable.colType} = ?',
      whereArgs: [userId, type],
      limit: 1,
    );
    if (rows.isNotEmpty) return 0;

    await addXp(
      userId: userId,
      amount: amount,
      type: type,
      description: description,
    );
    return amount;
  }

  /// +5 XP pour la première connexion de la journée.
  /// Retourne les XP gagnés (0 si déjà gagnés aujourd'hui).
  Future<int> awardDailyLogin(int userId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final db = await _db;
    final rows = await db.query(
      ActivityLogTable.tableName,
      where: '${ActivityLogTable.colUserId} = ? AND '
          '${ActivityLogTable.colType} = ? AND '
          '${ActivityLogTable.colCreatedAt} >= ? AND '
          '${ActivityLogTable.colCreatedAt} < ?',
      whereArgs: [
        userId,
        'login',
        start.toIso8601String(),
        end.toIso8601String(),
      ],
      limit: 1,
    );
    if (rows.isNotEmpty) return 0;

    await addXp(
      userId: userId,
      amount: 5,
      type: 'login',
      description: 'Connexion du jour',
    );
    return 5;
  }

  /// Historique d'un utilisateur, du plus récent au plus ancien.
  Future<List<ActivityLog>> getHistory(int userId, {int limit = 100}) async {
    final db = await _db;
    final rows = await db.query(
      ActivityLogTable.tableName,
      where: '${ActivityLogTable.colUserId} = ?',
      whereArgs: [userId],
      orderBy:
          '${ActivityLogTable.colCreatedAt} DESC, ${ActivityLogTable.colId} DESC',
      limit: limit,
    );
    return rows.map(ActivityLog.fromMap).toList();
  }

  /// Nombre de lignes d'un type donné (ex. 'login' = jours de connexion).
  Future<int> countByType(int userId, String type) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM ${ActivityLogTable.tableName} '
      'WHERE ${ActivityLogTable.colUserId} = ? AND '
      '${ActivityLogTable.colType} = ?',
      [userId, type],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}