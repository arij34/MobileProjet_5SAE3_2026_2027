import 'challenge_table.dart';

class ChallengeTaskProgress {
  const ChallengeTaskProgress({
    this.id,
    required this.participantId,
    required this.taskId,
    this.progress = 0,
    this.completed = false,
    this.completedAt,
    this.targetValue,
  });

  final int? id;
  final int participantId;
  final int taskId;
  final double progress;
  final bool completed;
  final DateTime? completedAt;
  final double? targetValue;

  Map<String, Object?> toMap() => {
    if (id != null) ChallengeTaskProgressTable.colId: id,
    ChallengeTaskProgressTable.colParticipantId: participantId,
    ChallengeTaskProgressTable.colTaskId: taskId,
    ChallengeTaskProgressTable.colProgress: progress,
    ChallengeTaskProgressTable.colCompleted: completed ? 1 : 0,
    ChallengeTaskProgressTable.colCompletedAt: completedAt?.toIso8601String(),
  };

  factory ChallengeTaskProgress.fromMap(Map<String, Object?> row) =>
      ChallengeTaskProgress(
        id: row[ChallengeTaskProgressTable.colId] as int?,
        participantId: row[ChallengeTaskProgressTable.colParticipantId] as int,
        taskId: row[ChallengeTaskProgressTable.colTaskId] as int,
        progress: (row[ChallengeTaskProgressTable.colProgress] as num)
            .toDouble(),
        completed: row[ChallengeTaskProgressTable.colCompleted] == 1,
        completedAt: row[ChallengeTaskProgressTable.colCompletedAt] == null
            ? null
            : DateTime.parse(
                row[ChallengeTaskProgressTable.colCompletedAt] as String,
              ),
        targetValue: (row['target_value'] as num?)?.toDouble(),
      );

  ChallengeTaskProgress copyWith({
    int? id,
    int? participantId,
    int? taskId,
    double? progress,
    bool? completed,
    Object? completedAt = _unchanged,
    double? targetValue,
  }) => ChallengeTaskProgress(
    id: id ?? this.id,
    participantId: participantId ?? this.participantId,
    taskId: taskId ?? this.taskId,
    progress: progress ?? this.progress,
    completed: completed ?? this.completed,
    completedAt: identical(completedAt, _unchanged)
        ? this.completedAt
        : completedAt as DateTime?,
    targetValue: targetValue ?? this.targetValue,
  );
}

const _unchanged = Object();
