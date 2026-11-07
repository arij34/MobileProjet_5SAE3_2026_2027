import 'notification_table.dart';
import 'notification_type.dart';

class AppNotification {
  final int? id;
  final int userId;
  final NotificationType type;
  final String title;
  final String body;
  final int? challengeId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.challengeId,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
    if (id != null) NotificationTable.colId: id,
    NotificationTable.colUserId: userId,
    NotificationTable.colType: type.value,
    NotificationTable.colTitle: title,
    NotificationTable.colBody: body,
    NotificationTable.colChallengeId: challengeId,
    NotificationTable.colIsRead: isRead ? 1 : 0,
    NotificationTable.colCreatedAt: createdAt.toIso8601String(),
  };

  factory AppNotification.fromMap(Map<String, Object?> map) => AppNotification(
    id: map[NotificationTable.colId] as int?,
    userId: map[NotificationTable.colUserId] as int,
    type: NotificationType.fromValue(map[NotificationTable.colType] as String),
    title: map[NotificationTable.colTitle] as String,
    body: map[NotificationTable.colBody] as String,
    challengeId: map[NotificationTable.colChallengeId] as int?,
    isRead: map[NotificationTable.colIsRead] == 1,
    createdAt: DateTime.parse(map[NotificationTable.colCreatedAt] as String),
  );

  AppNotification copyWith({
    int? id,
    int? userId,
    NotificationType? type,
    String? title,
    String? body,
    Object? challengeId = _unchanged,
    bool? isRead,
    DateTime? createdAt,
  }) => AppNotification(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    type: type ?? this.type,
    title: title ?? this.title,
    body: body ?? this.body,
    challengeId: identical(challengeId, _unchanged)
        ? this.challengeId
        : challengeId as int?,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt ?? this.createdAt,
  );
}

const Object _unchanged = Object();
