import 'activity_log_table.dart';

/// Une ligne du journal d'activités (historique + XP gagnés).
class ActivityLog {
  final int? id;
  final int userId;
  final String type; // 'registration', 'login', 'photo'...
  final String description;
  final int xp;
  final DateTime createdAt;

  const ActivityLog({
    this.id,
    required this.userId,
    required this.type,
    required this.description,
    required this.xp,
    required this.createdAt,
  });

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map[ActivityLogTable.colId] as int?,
      userId: map[ActivityLogTable.colUserId] as int,
      type: map[ActivityLogTable.colType] as String,
      description: map[ActivityLogTable.colDescription] as String,
      xp: (map[ActivityLogTable.colXp] as int?) ?? 0,
      createdAt: DateTime.parse(map[ActivityLogTable.colCreatedAt] as String),
    );
  }
}