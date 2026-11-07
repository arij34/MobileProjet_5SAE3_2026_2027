import 'challenge_table.dart';

class ChallengeTaskLog {
  const ChallengeTaskLog({
    this.id,
    required this.participantId,
    required this.taskId,
    required this.logDate,
    required this.amount,
    required this.createdAt,
    this.isEstimated = false,
  });

  final int? id;
  final int participantId;
  final int taskId;
  final DateTime logDate;
  final double amount;
  final DateTime createdAt;
  final bool isEstimated;

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<String, Object?> toMap() => {
    if (id != null) ChallengeTaskLogTable.colId: id,
    ChallengeTaskLogTable.colParticipantId: participantId,
    ChallengeTaskLogTable.colTaskId: taskId,
    ChallengeTaskLogTable.colLogDate: dateKey(logDate),
    ChallengeTaskLogTable.colAmount: amount,
    ChallengeTaskLogTable.colCreatedAt: createdAt.toIso8601String(),
    ChallengeTaskLogTable.colIsEstimated: isEstimated ? 1 : 0,
  };

  factory ChallengeTaskLog.fromMap(Map<String, Object?> map) =>
      ChallengeTaskLog(
        id: map[ChallengeTaskLogTable.colId] as int?,
        participantId: map[ChallengeTaskLogTable.colParticipantId] as int,
        taskId: map[ChallengeTaskLogTable.colTaskId] as int,
        logDate: DateTime.parse(
          map[ChallengeTaskLogTable.colLogDate] as String,
        ),
        amount: (map[ChallengeTaskLogTable.colAmount] as num).toDouble(),
        createdAt: DateTime.parse(
          map[ChallengeTaskLogTable.colCreatedAt] as String,
        ),
        isEstimated: map[ChallengeTaskLogTable.colIsEstimated] == 1,
      );

  ChallengeTaskLog copyWith({
    int? id,
    int? participantId,
    int? taskId,
    DateTime? logDate,
    double? amount,
    DateTime? createdAt,
    bool? isEstimated,
  }) => ChallengeTaskLog(
    id: id ?? this.id,
    participantId: participantId ?? this.participantId,
    taskId: taskId ?? this.taskId,
    logDate: logDate ?? this.logDate,
    amount: amount ?? this.amount,
    createdAt: createdAt ?? this.createdAt,
    isEstimated: isEstimated ?? this.isEstimated,
  );
}
