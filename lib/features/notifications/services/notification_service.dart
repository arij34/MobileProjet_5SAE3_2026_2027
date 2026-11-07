import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/session/session_manager.dart';
import '../../users/models/user_role.dart';
import '../../users/models/user_status.dart';
import '../../users/models/user_table.dart';
import '../models/app_notification.dart';
import '../models/notification_table.dart';
import '../models/notification_type.dart';

class NotificationException implements Exception {
  final String message;
  const NotificationException(this.message);

  @override
  String toString() => message;
}

class NotificationService {
  NotificationService._()
    : _database = (() => DatabaseHelper.instance.database);
  @visibleForTesting
  NotificationService.forDatabase(Future<Database> Function() database)
    : _database = database;
  static final NotificationService instance = NotificationService._();

  final Future<Database> Function() _database;
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  int _refreshGeneration = 0;

  int _currentUserId() {
    final user = SessionManager.instance.currentUser;
    if (user == null || !user.isActive || user.id == null) {
      throw const NotificationException('Session invalide, reconnectez-vous');
    }
    return user.id!;
  }

  void _checkSession(int userId) {
    if (_currentUserId() != userId) {
      throw const NotificationException('La session a changé');
    }
  }

  void resetUnreadCount() {
    _refreshGeneration++;
    unreadCount.value = 0;
  }

  Future<List<AppNotification>> getMyNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    if (limit <= 0 || offset < 0) {
      throw ArgumentError('Pagination invalide');
    }
    final userId = _currentUserId();
    final db = await _database();
    final rows = await db.query(
      NotificationTable.tableName,
      where: '${NotificationTable.colUserId} = ?',
      whereArgs: [userId],
      orderBy:
          '${NotificationTable.colCreatedAt} DESC, ${NotificationTable.colId} DESC',
      limit: limit,
      offset: offset,
    );
    _checkSession(userId);
    return rows.map(AppNotification.fromMap).toList();
  }

  Future<int> getUnreadCount() async {
    final userId = _currentUserId();
    final db = await _database();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) FROM ${NotificationTable.tableName} '
      'WHERE ${NotificationTable.colUserId} = ? AND ${NotificationTable.colIsRead} = 0',
      [userId],
    );
    _checkSession(userId);
    return Sqflite.firstIntValue(rows)!;
  }

  Future<void> refreshUnreadCount() async {
    final generation = ++_refreshGeneration;
    final userId = _currentUserId();
    final count = await getUnreadCount();
    if (generation == _refreshGeneration &&
        SessionManager.instance.currentUser?.id == userId) {
      unreadCount.value = count;
    }
  }

  Future<void> markAsRead(int id) async {
    final userId = _currentUserId();
    final db = await _database();
    _checkSession(userId);
    final changed = await db.update(
      NotificationTable.tableName,
      {NotificationTable.colIsRead: 1},
      where:
          '${NotificationTable.colId} = ? AND ${NotificationTable.colUserId} = ?',
      whereArgs: [id, userId],
    );
    if (changed == 0) {
      throw const NotificationException('Notification introuvable');
    }
    await refreshUnreadCount();
  }

  Future<void> markAllAsRead() async {
    final userId = _currentUserId();
    final db = await _database();
    _checkSession(userId);
    await db.update(
      NotificationTable.tableName,
      {NotificationTable.colIsRead: 1},
      where:
          '${NotificationTable.colUserId} = ? AND ${NotificationTable.colIsRead} = 0',
      whereArgs: [userId],
    );
    await refreshUnreadCount();
  }

  Future<void> deleteNotification(int id) async {
    final userId = _currentUserId();
    final db = await _database();
    _checkSession(userId);
    final changed = await db.delete(
      NotificationTable.tableName,
      where:
          '${NotificationTable.colId} = ? AND ${NotificationTable.colUserId} = ?',
      whereArgs: [id, userId],
    );
    if (changed == 0) {
      throw const NotificationException('Notification introuvable');
    }
    await refreshUnreadCount();
  }

  Future<void> clearAll() async {
    final userId = _currentUserId();
    final db = await _database();
    _checkSession(userId);
    await db.delete(
      NotificationTable.tableName,
      where: '${NotificationTable.colUserId} = ?',
      whereArgs: [userId],
    );
    await refreshUnreadCount();
  }

  /// Called with the challenge transaction so the event and notifications commit together.
  Future<void> insertForRole(
    DatabaseExecutor txn, {
    required UserRole role,
    required int actorId,
    required NotificationType type,
    required String title,
    required String body,
    required int challengeId,
    required DateTime createdAt,
  }) async {
    final users = await txn.query(
      UserTable.tableName,
      columns: [UserTable.colId],
      where:
          '${UserTable.colRole} = ? AND ${UserTable.colStatus} = ? AND ${UserTable.colId} != ?',
      whereArgs: [role.value, UserStatus.active.value, actorId],
    );
    await insertBatch(
      txn,
      recipients: users.map((u) => u[UserTable.colId] as int),
      actorId: actorId,
      type: type,
      title: title,
      body: body,
      challengeId: challengeId,
      createdAt: createdAt,
    );
  }

  Future<void> insertBatch(
    DatabaseExecutor txn, {
    required Iterable<int> recipients,
    required int actorId,
    required NotificationType type,
    required String title,
    required String body,
    required int challengeId,
    required DateTime createdAt,
  }) async {
    final batch = txn.batch();
    for (final userId in recipients.toSet().where((id) => id != actorId)) {
      batch.insert(
        NotificationTable.tableName,
        AppNotification(
          userId: userId,
          type: type,
          title: title,
          body: body,
          challengeId: challengeId,
          createdAt: createdAt,
        ).toMap(),
      );
    }
    await batch.commit(noResult: true);
  }
}
