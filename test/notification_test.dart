import 'package:flutter_test/flutter_test.dart';
import 'package:mygym/core/session/session_manager.dart';
import 'package:mygym/features/notifications/models/app_notification.dart';
import 'package:mygym/features/notifications/models/notification_table.dart';
import 'package:mygym/features/notifications/models/notification_type.dart';
import 'package:mygym/features/notifications/services/notification_service.dart';
import 'package:mygym/features/users/models/user.dart';
import 'package:mygym/features/users/models/user_role.dart';
import 'package:mygym/features/users/models/user_status.dart';
import 'package:sqflite/sqflite.dart';

class _DatabaseFake implements Database {
  final List<Map<String, Object?>> notifications = [];
  final List<Map<String, Object?>> users = [];

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (table == 'users') {
      expect(where, 'role = ? AND status = ? AND id != ?');
      return users
          .where(
            (u) =>
                u['role'] == whereArgs![0] &&
                u['status'] == whereArgs[1] &&
                u['id'] != whereArgs[2],
          )
          .toList();
    }
    expect(where, 'user_id = ?');
    final rows =
        notifications.where((n) => n['user_id'] == whereArgs![0]).toList()
          ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    return rows.skip(offset ?? 0).take(limit ?? rows.length).toList();
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    expect(sql, contains('user_id = ? AND is_read = 0'));
    return [
      {
        'COUNT(*)': notifications
            .where((n) => n['user_id'] == arguments![0] && n['is_read'] == 0)
            .length,
      },
    ];
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final individual = where == 'id = ? AND user_id = ?';
    expect(
      where,
      individual ? 'id = ? AND user_id = ?' : 'user_id = ? AND is_read = 0',
    );
    final selected = notifications
        .where(
          (n) => individual
              ? n['id'] == whereArgs![0] && n['user_id'] == whereArgs[1]
              : n['user_id'] == whereArgs![0] && n['is_read'] == 0,
        )
        .toList();
    for (final n in selected) {
      n.addAll(values);
    }
    return selected.length;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final individual = where == 'id = ? AND user_id = ?';
    expect(where, individual ? 'id = ? AND user_id = ?' : 'user_id = ?');
    final before = notifications.length;
    notifications.removeWhere(
      (n) => individual
          ? n['id'] == whereArgs![0] && n['user_id'] == whereArgs[1]
          : n['user_id'] == whereArgs![0],
    );
    return before - notifications.length;
  }

  @override
  Batch batch() => _BatchFake(notifications);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BatchFake implements Batch {
  _BatchFake(this.rows);
  final List<Map<String, Object?>> rows;
  final List<Map<String, Object?>> pending = [];
  @override
  void insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    expect(table, NotificationTable.tableName);
    pending.add(values);
  }

  @override
  Future<List<Object?>> commit({
    bool? exclusive,
    bool? noResult,
    bool? continueOnError,
  }) async {
    expect(noResult, isTrue);
    for (final row in pending) {
      rows.add({...row, 'id': rows.length + 1});
    }
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime(2026, 11, 6);
  User user(int id) => User(
    id: id,
    firstName: 'Test',
    lastName: 'User',
    email: 'test$id@example.com',
    passwordHash: 'hash',
    phone: '123',
    createdAt: now,
  );
  AppNotification notification(int id, int userId, {bool read = false}) =>
      AppNotification(
        id: id,
        userId: userId,
        type: NotificationType.challengeRejected,
        title: 'Rejeté',
        body: 'Motif de rejet',
        challengeId: 7,
        isRead: read,
        createdAt: now,
      );

  late _DatabaseFake db;
  late NotificationService service;
  setUp(() {
    db = _DatabaseFake();
    service = NotificationService.forDatabase(() async => db);
    SessionManager.instance.currentUser = user(1);
  });
  tearDown(() {
    SessionManager.instance.logout();
    service.unreadCount.dispose();
  });

  test('notification round trip and explicit nullable copy', () {
    final original = notification(1, 1);
    final copy = AppNotification.fromMap(original.toMap());
    expect(copy.toMap(), original.toMap());
    expect(copy.copyWith(challengeId: null).challengeId, isNull);
    expect(() => NotificationType.fromValue('unknown'), throwsFormatException);
  });

  test('only own notifications can be read, changed or deleted', () async {
    db.notifications.addAll([
      notification(1, 1).toMap(),
      notification(2, 2).toMap(),
    ]);
    expect((await service.getMyNotifications()).map((n) => n.id), [1]);
    await expectLater(
      service.markAsRead(2),
      throwsA(isA<NotificationException>()),
    );
    await expectLater(
      service.deleteNotification(2),
      throwsA(isA<NotificationException>()),
    );
    expect(db.notifications.last['is_read'], 0);
    await service.markAsRead(1);
    expect(db.notifications.first['is_read'], 1);
    await service.clearAll();
    expect(db.notifications.single['user_id'], 2);
  });

  test('mark all and unread notifier are scoped to current user', () async {
    db.notifications.addAll([
      notification(1, 1).toMap(),
      notification(2, 1).toMap(),
      notification(3, 2).toMap(),
    ]);
    await service.refreshUnreadCount();
    expect(service.unreadCount.value, 2);
    await service.markAllAsRead();
    expect(service.unreadCount.value, 0);
    expect(await service.getUnreadCount(), 0);
    expect(db.notifications.last['is_read'], 0);
    SessionManager.instance.currentUser = user(2);
    await service.refreshUnreadCount();
    expect(service.unreadCount.value, 1);
  });

  test('batch delivery targets active role and excludes actor', () async {
    db.users.addAll([
      {'id': 1, 'role': 'member', 'status': 'active'},
      {'id': 2, 'role': 'member', 'status': 'active'},
      {'id': 3, 'role': 'member', 'status': 'disabled'},
      {'id': 4, 'role': 'admin', 'status': 'active'},
    ]);
    await service.insertForRole(
      db,
      role: UserRole.member,
      actorId: 1,
      type: NotificationType.challengePosted,
      title: 'Nouveau challenge',
      body: 'Test',
      challengeId: 7,
      createdAt: now,
    );
    expect(db.notifications.map((row) => row['user_id']), [2]);
    await service.insertBatch(
      db,
      recipients: [1, 4, 4],
      actorId: 1,
      type: NotificationType.challengePendingReview,
      title: 'Validation',
      body: 'Test',
      challengeId: 7,
      createdAt: now,
    );
    expect(db.notifications.map((row) => row['user_id']), [2, 4]);
  });

  test('inactive and signed-out sessions are rejected', () async {
    SessionManager.instance.currentUser = user(1)
        .copyWith(status: UserStatus.disabled);
    await expectLater(
      service.getMyNotifications(),
      throwsA(isA<NotificationException>()),
    );
    SessionManager.instance.logout();
    await expectLater(
      service.clearAll(),
      throwsA(isA<NotificationException>()),
    );
  });
}
