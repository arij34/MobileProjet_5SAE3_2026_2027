import 'coach_enums.dart';
import 'gym_coach_tables.dart';

/// Un coach rattaché à une salle.
class GymCoach {
  final int? id;
  final int gymId;
  final int coachId;
  final String specialty;
  final double hourlyRate;
  final String availability;
  final GymCoachStatus status;
  final DateTime joinedAt;

  // Remplis par les requêtes avec jointure (lecture seule).
  final String? coachName;
  final String? gymName;
  final String? gymCity;

  const GymCoach({
    this.id,
    required this.gymId,
    required this.coachId,
    this.specialty = '',
    this.hourlyRate = 0,
    this.availability = '',
    this.status = GymCoachStatus.active,
    required this.joinedAt,
    this.coachName,
    this.gymName,
    this.gymCity,
  });

  bool get isActive => status == GymCoachStatus.active;

  Map<String, dynamic> toMap() => {
        if (id != null) GymCoachTable.colId: id,
        GymCoachTable.colGymId: gymId,
        GymCoachTable.colCoachId: coachId,
        GymCoachTable.colSpecialty: specialty,
        GymCoachTable.colHourlyRate: hourlyRate,
        GymCoachTable.colAvailability: availability,
        GymCoachTable.colStatus: status.value,
        GymCoachTable.colJoinedAt: joinedAt.toIso8601String(),
      };

  factory GymCoach.fromMap(Map<String, dynamic> map) => GymCoach(
        id: map[GymCoachTable.colId] as int?,
        gymId: map[GymCoachTable.colGymId] as int,
        coachId: map[GymCoachTable.colCoachId] as int,
        specialty: (map[GymCoachTable.colSpecialty] as String?) ?? '',
        hourlyRate:
            ((map[GymCoachTable.colHourlyRate] as num?) ?? 0).toDouble(),
        availability: (map[GymCoachTable.colAvailability] as String?) ?? '',
        status:
            GymCoachStatus.fromValue(map[GymCoachTable.colStatus] as String?),
        joinedAt: DateTime.parse(map[GymCoachTable.colJoinedAt] as String),
        coachName: map['coach_name'] as String?,
        gymName: map['gym_name'] as String?,
        gymCity: map['gym_city'] as String?,
      );

  GymCoach copyWith({
    String? specialty,
    double? hourlyRate,
    String? availability,
    GymCoachStatus? status,
  }) =>
      GymCoach(
        id: id,
        gymId: gymId,
        coachId: coachId,
        specialty: specialty ?? this.specialty,
        hourlyRate: hourlyRate ?? this.hourlyRate,
        availability: availability ?? this.availability,
        status: status ?? this.status,
        joinedAt: joinedAt,
        coachName: coachName,
        gymName: gymName,
        gymCity: gymCity,
      );
}
