import 'challenge_difficulty.dart';
import 'challenge_status.dart';
import 'challenge_table.dart';
import 'challenge_task.dart';

/// Date au format jj/mm/aaaa pour l'affichage.
String formatChallengeDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

class Challenge {
  final int? id;
  final String title;
  final String description;
  final ChallengeDifficulty difficulty;
  final int xpReward;
  final DateTime startDate;
  final DateTime endDate;
  final ChallengeStatus status;
  final String? imagePath;
  final int createdBy; // users.id du créateur
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? rejectionReason;
  final int? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewerName;

  // Les tâches sont dans la table challenge_tasks, pas dans challenges.
  final List<ChallengeTask> tasks;

  // Nom du créateur, rempli par les lectures (jointure) ; jamais enregistré.
  final String? creatorName;

  // Nombre de tâches, rempli par les lectures de liste (sans charger les tâches).
  final int? taskCountOverride;

  const Challenge({
    this.id,
    required this.title,
    this.description = '',
    this.difficulty = ChallengeDifficulty.medium,
    required this.xpReward,
    required this.startDate,
    required this.endDate,
    this.status = ChallengeStatus.draft,
    this.imagePath,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.rejectionReason,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewerName,
    this.tasks = const [],
    this.creatorName,
    this.taskCountOverride,
  });

  int get taskCount => taskCountOverride ?? tasks.length;

  int get totalDays =>
      DateTime.utc(endDate.year, endDate.month, endDate.day)
          .difference(
            DateTime.utc(startDate.year, startDate.month, startDate.day),
          )
          .inDays +
      1;

  int? dayNumberAt(DateTime now) {
    final day = DateTime.utc(now.year, now.month, now.day);
    final start = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final number = day.difference(start).inDays + 1;
    if (number < 1) return null;
    return number > totalDays ? totalDays : number;
  }

  int? get currentDayNumber => dayNumberAt(DateTime.now());

  /// À venir / en cours / terminé, calculé à partir des dates.
  ChallengeTimeState timeStateAt(DateTime now) {
    final day = DateTime.utc(now.year, now.month, now.day);
    final start = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final end = DateTime.utc(endDate.year, endDate.month, endDate.day);
    if (day.isBefore(start)) return ChallengeTimeState.upcoming;
    if (day.isAfter(end)) return ChallengeTimeState.ended;
    return ChallengeTimeState.ongoing;
  }

  ChallengeTimeState get timeState => timeStateAt(DateTime.now());

  Map<String, dynamic> toMap() {
    return {
      if (id != null) ChallengeTable.colId: id,
      ChallengeTable.colTitle: title,
      ChallengeTable.colDescription: description,
      ChallengeTable.colDifficulty: difficulty.value,
      ChallengeTable.colXpReward: xpReward,
      ChallengeTable.colStartDate: startDate.toIso8601String(),
      ChallengeTable.colEndDate: endDate.toIso8601String(),
      ChallengeTable.colStatus: status.value,
      ChallengeTable.colImagePath: imagePath,
      ChallengeTable.colCreatedBy: createdBy,
      ChallengeTable.colCreatedAt: createdAt.toIso8601String(),
      ChallengeTable.colUpdatedAt: updatedAt.toIso8601String(),
      ChallengeTable.colRejectionReason: rejectionReason,
      ChallengeTable.colReviewedBy: reviewedBy,
      ChallengeTable.colReviewedAt: reviewedAt?.toIso8601String(),
    };
  }

  factory Challenge.fromMap(
    Map<String, dynamic> map, {
    List<ChallengeTask> tasks = const [],
  }) {
    return Challenge(
      id: map[ChallengeTable.colId] as int?,
      title: map[ChallengeTable.colTitle] as String,
      description: (map[ChallengeTable.colDescription] as String?) ?? '',
      difficulty: ChallengeDifficulty.fromValue(
        map[ChallengeTable.colDifficulty] as String?,
      ),
      xpReward: map[ChallengeTable.colXpReward] as int,
      startDate: DateTime.parse(map[ChallengeTable.colStartDate] as String),
      endDate: DateTime.parse(map[ChallengeTable.colEndDate] as String),
      status: ChallengeStatus.fromValue(
        map[ChallengeTable.colStatus] as String?,
      ),
      imagePath: map[ChallengeTable.colImagePath] as String?,
      createdBy: map[ChallengeTable.colCreatedBy] as int,
      createdAt: DateTime.parse(map[ChallengeTable.colCreatedAt] as String),
      updatedAt: DateTime.parse(map[ChallengeTable.colUpdatedAt] as String),
      rejectionReason: map[ChallengeTable.colRejectionReason] as String?,
      reviewedBy: map[ChallengeTable.colReviewedBy] as int?,
      reviewedAt: map[ChallengeTable.colReviewedAt] == null
          ? null
          : DateTime.parse(map[ChallengeTable.colReviewedAt] as String),
      reviewerName: map[ChallengeTable.colReviewerName] as String?,
      tasks: tasks,
      creatorName: map[ChallengeTable.colCreatorName] as String?,
      taskCountOverride: map['task_count'] as int?,
    );
  }

  Challenge copyWith({
    int? id,
    String? title,
    String? description,
    ChallengeDifficulty? difficulty,
    int? xpReward,
    DateTime? startDate,
    DateTime? endDate,
    ChallengeStatus? status,
    String? imagePath,
    int? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ChallengeTask>? tasks,
    String? creatorName,
    Object? rejectionReason = _unchanged,
    Object? reviewedBy = _unchanged,
    Object? reviewedAt = _unchanged,
    String? reviewerName,
  }) {
    return Challenge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      xpReward: xpReward ?? this.xpReward,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      imagePath: imagePath ?? this.imagePath,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rejectionReason: identical(rejectionReason, _unchanged)
          ? this.rejectionReason
          : rejectionReason as String?,
      reviewedBy: identical(reviewedBy, _unchanged)
          ? this.reviewedBy
          : reviewedBy as int?,
      reviewedAt: identical(reviewedAt, _unchanged)
          ? this.reviewedAt
          : reviewedAt as DateTime?,
      reviewerName: reviewerName ?? this.reviewerName,
      tasks: tasks ?? this.tasks,
      creatorName: creatorName ?? this.creatorName,
      taskCountOverride: taskCountOverride,
    );
  }
}

const Object _unchanged = Object();
