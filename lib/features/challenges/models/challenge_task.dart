import 'dart:convert';

import 'challenge_table.dart';
import 'challenge_task_log.dart';
import 'challenge_type.dart';
import 'challenge_unit.dart';

/// Une tâche avec des dates facultatives ; une liste vide signifie automatique.
class ChallengeTask {
  final int? id;
  final int challengeId;
  final String title;
  final String? description;
  final ChallengeType type;
  final ChallengeUnit unit;
  final double targetValue; // toujours > 0
  final int xpReward;
  final int orderIndex;
  final List<DateTime> scheduledDates;

  const ChallengeTask({
    this.id,
    this.challengeId = 0,
    required this.title,
    this.description,
    this.type = ChallengeType.custom,
    this.unit = ChallengeUnit.reps,
    required this.targetValue,
    this.xpReward = 0,
    this.orderIndex = 0,
    this.scheduledDates = const [],
  });

  bool isScheduledOn(DateTime day) =>
      scheduledDates.isEmpty ||
      scheduledDates.any(
        (date) =>
            ChallengeTaskLog.dateKey(date) == ChallengeTaskLog.dateKey(day),
      );

  static List<DateTime> decodeScheduledDates(Object? encoded) => encoded == null
      ? const []
      : (jsonDecode(encoded as String) as List)
            .map((date) => DateTime.parse(date as String))
            .toList();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) ChallengeTaskTable.colId: id,
      ChallengeTaskTable.colChallengeId: challengeId,
      ChallengeTaskTable.colTitle: title,
      ChallengeTaskTable.colDescription: description,
      ChallengeTaskTable.colType: type.value,
      ChallengeTaskTable.colUnit: unit.value,
      ChallengeTaskTable.colTargetValue: targetValue,
      ChallengeTaskTable.colXpReward: xpReward,
      ChallengeTaskTable.colOrderIndex: orderIndex,
      ChallengeTaskTable.colScheduledDates: scheduledDates.isEmpty
          ? null
          : jsonEncode(scheduledDates.map(ChallengeTaskLog.dateKey).toList()),
    };
  }

  factory ChallengeTask.fromMap(Map<String, dynamic> map) {
    return ChallengeTask(
      id: map[ChallengeTaskTable.colId] as int?,
      challengeId: map[ChallengeTaskTable.colChallengeId] as int,
      title: map[ChallengeTaskTable.colTitle] as String,
      description: map[ChallengeTaskTable.colDescription] as String?,
      type: ChallengeType.fromValue(map[ChallengeTaskTable.colType] as String?),
      unit: ChallengeUnit.fromValue(map[ChallengeTaskTable.colUnit] as String?),
      targetValue: (map[ChallengeTaskTable.colTargetValue] as num).toDouble(),
      xpReward: (map[ChallengeTaskTable.colXpReward] as int?) ?? 0,
      orderIndex: (map[ChallengeTaskTable.colOrderIndex] as int?) ?? 0,
      scheduledDates: decodeScheduledDates(
        map[ChallengeTaskTable.colScheduledDates],
      ),
    );
  }

  ChallengeTask copyWith({
    int? id,
    int? challengeId,
    String? title,
    String? description,
    ChallengeType? type,
    ChallengeUnit? unit,
    double? targetValue,
    int? xpReward,
    int? orderIndex,
    List<DateTime>? scheduledDates,
  }) {
    return ChallengeTask(
      id: id ?? this.id,
      challengeId: challengeId ?? this.challengeId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      unit: unit ?? this.unit,
      targetValue: targetValue ?? this.targetValue,
      xpReward: xpReward ?? this.xpReward,
      orderIndex: orderIndex ?? this.orderIndex,
      scheduledDates: scheduledDates ?? this.scheduledDates,
    );
  }
}
