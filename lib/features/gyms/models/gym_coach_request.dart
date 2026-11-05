import 'coach_enums.dart';
import 'gym_coach_tables.dart';

/// Invitation (salle -> coach) ou candidature (coach -> salle).
class GymCoachRequest {
  final int? id;
  final int gymId;
  final int coachId;
  final CoachRequestInitiator initiatedBy;
  final CoachRequestStatus status;
  final String message;
  final DateTime createdAt;
  final DateTime? respondedAt;

  // Remplis par les requêtes avec jointure (lecture seule).
  final String? coachName;
  final String? gymName;
  final String? gymCity;

  const GymCoachRequest({
    this.id,
    required this.gymId,
    required this.coachId,
    required this.initiatedBy,
    this.status = CoachRequestStatus.pending,
    this.message = '',
    required this.createdAt,
    this.respondedAt,
    this.coachName,
    this.gymName,
    this.gymCity,
  });

  bool get isPending => status == CoachRequestStatus.pending;

  Map<String, dynamic> toMap() => {
        if (id != null) GymCoachRequestTable.colId: id,
        GymCoachRequestTable.colGymId: gymId,
        GymCoachRequestTable.colCoachId: coachId,
        GymCoachRequestTable.colInitiatedBy: initiatedBy.value,
        GymCoachRequestTable.colStatus: status.value,
        GymCoachRequestTable.colMessage: message,
        GymCoachRequestTable.colCreatedAt: createdAt.toIso8601String(),
        GymCoachRequestTable.colRespondedAt: respondedAt?.toIso8601String(),
      };

  factory GymCoachRequest.fromMap(Map<String, dynamic> map) {
    final responded = map[GymCoachRequestTable.colRespondedAt] as String?;
    return GymCoachRequest(
      id: map[GymCoachRequestTable.colId] as int?,
      gymId: map[GymCoachRequestTable.colGymId] as int,
      coachId: map[GymCoachRequestTable.colCoachId] as int,
      initiatedBy: CoachRequestInitiator.fromValue(
          map[GymCoachRequestTable.colInitiatedBy] as String?),
      status: CoachRequestStatus.fromValue(
          map[GymCoachRequestTable.colStatus] as String?),
      message: (map[GymCoachRequestTable.colMessage] as String?) ?? '',
      createdAt:
          DateTime.parse(map[GymCoachRequestTable.colCreatedAt] as String),
      respondedAt: responded == null ? null : DateTime.tryParse(responded),
      coachName: map['coach_name'] as String?,
      gymName: map['gym_name'] as String?,
      gymCity: map['gym_city'] as String?,
    );
  }
}
