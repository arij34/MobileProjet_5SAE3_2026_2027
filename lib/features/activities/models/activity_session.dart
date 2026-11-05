import 'activity_category.dart';
import 'activity_session_table.dart';

/// Une séance planifiée d'une activité (créneau précis avec capacité).
class ActivitySession {
  final int? id;
  final int activityId;
  final int? coachId;
  final DateTime startAt;
  final int durationMin;
  final int capacityMax;
  final DateTime createdAt;

  // Remplis par les requêtes avec jointure (lecture seule, jamais stockés ici).
  final String? activityName;
  final ActivityCategory? activityCategory;
  final int? gymId;
  final String? gymName;
  final String? coachName;
  final int confirmedCount; // réservations confirmées
  final int waitlistCount; // adhérents en liste d'attente

  const ActivitySession({
    this.id,
    required this.activityId,
    this.coachId,
    required this.startAt,
    this.durationMin = 60,
    this.capacityMax = 1,
    required this.createdAt,
    this.activityName,
    this.activityCategory,
    this.gymId,
    this.gymName,
    this.coachName,
    this.confirmedCount = 0,
    this.waitlistCount = 0,
  });

  DateTime get endAt => startAt.add(Duration(minutes: durationMin));

  /// Places encore libres (jamais négatif).
  int get remaining {
    final left = capacityMax - confirmedCount;
    return left < 0 ? 0 : left;
  }

  bool get isFull => remaining <= 0;

  /// Séance déjà commencée / passée ?
  bool get isPast => startAt.isBefore(DateTime.now());

  bool get isUpcoming => !isPast;

  static String two(int n) => n.toString().padLeft(2, '0');

  String get dateLabel =>
      '${two(startAt.day)}/${two(startAt.month)}/${startAt.year}';

  String get timeLabel => '${two(startAt.hour)}:${two(startAt.minute)}';

  String get timeRangeLabel =>
      '$timeLabel - ${two(endAt.hour)}:${two(endAt.minute)}';

  Map<String, dynamic> toMap() => {
        if (id != null) ActivitySessionTable.colId: id,
        ActivitySessionTable.colActivityId: activityId,
        ActivitySessionTable.colCoachId: coachId,
        ActivitySessionTable.colStartAt: startAt.toIso8601String(),
        ActivitySessionTable.colDurationMin: durationMin,
        ActivitySessionTable.colCapacityMax: capacityMax,
        ActivitySessionTable.colCreatedAt: createdAt.toIso8601String(),
      };

  factory ActivitySession.fromMap(Map<String, dynamic> map) => ActivitySession(
        id: map[ActivitySessionTable.colId] as int?,
        activityId: map[ActivitySessionTable.colActivityId] as int,
        coachId: map[ActivitySessionTable.colCoachId] as int?,
        startAt: DateTime.parse(map[ActivitySessionTable.colStartAt] as String),
        durationMin: (map[ActivitySessionTable.colDurationMin] as int?) ?? 60,
        capacityMax: (map[ActivitySessionTable.colCapacityMax] as int?) ?? 1,
        createdAt:
            DateTime.parse(map[ActivitySessionTable.colCreatedAt] as String),
        activityName: map['activity_name'] as String?,
        activityCategory: map['activity_category'] == null
            ? null
            : ActivityCategory.fromValue(map['activity_category'] as String?),
        gymId: map['gym_id'] as int?,
        gymName: map['gym_name'] as String?,
        coachName: map['coach_name'] as String?,
        confirmedCount: (map['confirmed_count'] as int?) ?? 0,
        waitlistCount: (map['waitlist_count'] as int?) ?? 0,
      );

  ActivitySession copyWith({
    int? id,
    int? activityId,
    int? coachId,
    bool clearCoach = false,
    DateTime? startAt,
    int? durationMin,
    int? capacityMax,
    DateTime? createdAt,
  }) =>
      ActivitySession(
        id: id ?? this.id,
        activityId: activityId ?? this.activityId,
        coachId: clearCoach ? null : (coachId ?? this.coachId),
        startAt: startAt ?? this.startAt,
        durationMin: durationMin ?? this.durationMin,
        capacityMax: capacityMax ?? this.capacityMax,
        createdAt: createdAt ?? this.createdAt,
        activityName: activityName,
        activityCategory: activityCategory,
        gymId: gymId,
        gymName: gymName,
        coachName: coachName,
        confirmedCount: confirmedCount,
        waitlistCount: waitlistCount,
      );
}
