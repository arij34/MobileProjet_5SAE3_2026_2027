import 'activity_category.dart';
import 'activity_level.dart';
import 'activity_table.dart';

/// Une activité sportive proposée par une salle (ex. « Yoga doux »).
class Activity {
  final int? id;
  final int gymId;
  final String name;
  final String description;
  final ActivityCategory category;
  final int durationMin;
  final ActivityLevel level;
  final String objective;
  final DateTime createdAt;

  // Rempli par les requêtes avec jointure (lecture seule).
  final String? gymName;
  final String? gymCity;
  final int? sessionCount; // nombre de séances planifiées pour cette activité

  const Activity({
    this.id,
    required this.gymId,
    required this.name,
    this.description = '',
    this.category = ActivityCategory.other,
    this.durationMin = 60,
    this.level = ActivityLevel.beginner,
    this.objective = '',
    required this.createdAt,
    this.gymName,
    this.gymCity,
    this.sessionCount,
  });

  String get durationLabel {
    if (durationMin < 60) return '$durationMin min';
    final h = durationMin ~/ 60;
    final m = durationMin % 60;
    return m == 0 ? '${h}h' : '${h}h$m';
  }

  Map<String, dynamic> toMap() => {
        if (id != null) ActivityTable.colId: id,
        ActivityTable.colGymId: gymId,
        ActivityTable.colName: name,
        ActivityTable.colDescription: description,
        ActivityTable.colCategory: category.value,
        ActivityTable.colDurationMin: durationMin,
        ActivityTable.colLevel: level.value,
        ActivityTable.colObjective: objective,
        ActivityTable.colCreatedAt: createdAt.toIso8601String(),
      };

  factory Activity.fromMap(Map<String, dynamic> map) => Activity(
        id: map[ActivityTable.colId] as int?,
        gymId: map[ActivityTable.colGymId] as int,
        name: map[ActivityTable.colName] as String,
        description: (map[ActivityTable.colDescription] as String?) ?? '',
        category:
            ActivityCategory.fromValue(map[ActivityTable.colCategory] as String?),
        durationMin: (map[ActivityTable.colDurationMin] as int?) ?? 60,
        level: ActivityLevel.fromValue(map[ActivityTable.colLevel] as String?),
        objective: (map[ActivityTable.colObjective] as String?) ?? '',
        createdAt: DateTime.parse(map[ActivityTable.colCreatedAt] as String),
        gymName: map['gym_name'] as String?,
        gymCity: map['gym_city'] as String?,
        sessionCount: map['session_count'] as int?,
      );

  Activity copyWith({
    int? id,
    int? gymId,
    String? name,
    String? description,
    ActivityCategory? category,
    int? durationMin,
    ActivityLevel? level,
    String? objective,
    DateTime? createdAt,
  }) =>
      Activity(
        id: id ?? this.id,
        gymId: gymId ?? this.gymId,
        name: name ?? this.name,
        description: description ?? this.description,
        category: category ?? this.category,
        durationMin: durationMin ?? this.durationMin,
        level: level ?? this.level,
        objective: objective ?? this.objective,
        createdAt: createdAt ?? this.createdAt,
        gymName: gymName,
        gymCity: gymCity,
        sessionCount: sessionCount,
      );
}
