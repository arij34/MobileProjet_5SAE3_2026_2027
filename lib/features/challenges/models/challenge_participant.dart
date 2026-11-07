import 'challenge_table.dart';
import 'challenge_task_progress.dart';
import 'participant_status.dart';

class ChallengeParticipant {
  const ChallengeParticipant({
    this.id,
    required this.challengeId,
    required this.userId,
    required this.status,
    required this.joinedAt,
    this.completedAt,
    this.tasks = const [],
  });

  final int? id;
  final int challengeId;
  final int userId;
  final ParticipantStatus status;
  final DateTime joinedAt;
  final DateTime? completedAt;
  final List<ChallengeTaskProgress> tasks;

  double get progressPercent => tasks.isEmpty
      ? 0
      : tasks.fold<double>(0, (sum, task) {
              final target = task.targetValue;
              return sum +
                  (target != null && target > 0
                      ? (task.progress / target).clamp(0, 1)
                      : (task.completed ? 1 : 0));
            }) /
            tasks.length *
            100;

  Map<String, Object?> toMap() => {
    if (id != null) ChallengeParticipantTable.colId: id,
    ChallengeParticipantTable.colChallengeId: challengeId,
    ChallengeParticipantTable.colUserId: userId,
    ChallengeParticipantTable.colStatus: status.value,
    ChallengeParticipantTable.colJoinedAt: joinedAt.toIso8601String(),
    ChallengeParticipantTable.colCompletedAt: completedAt?.toIso8601String(),
  };

  factory ChallengeParticipant.fromMap(
    Map<String, Object?> row, {
    List<ChallengeTaskProgress> tasks = const [],
  }) => ChallengeParticipant(
    id: row[ChallengeParticipantTable.colId] as int?,
    challengeId: row[ChallengeParticipantTable.colChallengeId] as int,
    userId: row[ChallengeParticipantTable.colUserId] as int,
    status: ParticipantStatus.fromValue(
      row[ChallengeParticipantTable.colStatus] as String,
    ),
    joinedAt: DateTime.parse(
      row[ChallengeParticipantTable.colJoinedAt] as String,
    ),
    completedAt: row[ChallengeParticipantTable.colCompletedAt] == null
        ? null
        : DateTime.parse(
            row[ChallengeParticipantTable.colCompletedAt] as String,
          ),
    tasks: tasks,
  );

  ChallengeParticipant copyWith({
    int? id,
    int? challengeId,
    int? userId,
    ParticipantStatus? status,
    DateTime? joinedAt,
    Object? completedAt = _unchanged,
    List<ChallengeTaskProgress>? tasks,
  }) => ChallengeParticipant(
    id: id ?? this.id,
    challengeId: challengeId ?? this.challengeId,
    userId: userId ?? this.userId,
    status: status ?? this.status,
    joinedAt: joinedAt ?? this.joinedAt,
    completedAt: identical(completedAt, _unchanged)
        ? this.completedAt
        : completedAt as DateTime?,
    tasks: tasks ?? this.tasks,
  );
}

const _unchanged = Object();
