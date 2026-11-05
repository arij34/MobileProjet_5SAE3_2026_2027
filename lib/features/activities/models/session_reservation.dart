import 'activity_session.dart';
import 'reservation_status.dart';
import 'session_reservation_table.dart';

/// Une réservation d'un adhérent pour une séance.
class SessionReservation {
  final int? id;
  final int sessionId;
  final int userId;
  final ReservationStatus status;
  final String? googleEventId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Remplis par les requêtes avec jointure (lecture seule).
  final String? memberName;
  final String? memberEmail;
  final ActivitySession? session; // détails de la séance (pour l'historique)

  const SessionReservation({
    this.id,
    required this.sessionId,
    required this.userId,
    this.status = ReservationStatus.confirmed,
    this.googleEventId,
    required this.createdAt,
    required this.updatedAt,
    this.memberName,
    this.memberEmail,
    this.session,
  });

  bool get isActive => ReservationStatus.active.contains(status);
  bool get isConfirmed => status == ReservationStatus.confirmed;
  bool get isWaitlisted => status == ReservationStatus.waitlisted;

  Map<String, dynamic> toMap() => {
        if (id != null) SessionReservationTable.colId: id,
        SessionReservationTable.colSessionId: sessionId,
        SessionReservationTable.colUserId: userId,
        SessionReservationTable.colStatus: status.value,
        SessionReservationTable.colGoogleEventId: googleEventId,
        SessionReservationTable.colCreatedAt: createdAt.toIso8601String(),
        SessionReservationTable.colUpdatedAt: updatedAt.toIso8601String(),
      };

  factory SessionReservation.fromMap(Map<String, dynamic> map) {
    return SessionReservation(
      id: map[SessionReservationTable.colId] as int?,
      sessionId: map[SessionReservationTable.colSessionId] as int,
      userId: map[SessionReservationTable.colUserId] as int,
      status: ReservationStatus.fromValue(
          map[SessionReservationTable.colStatus] as String?),
      googleEventId: map[SessionReservationTable.colGoogleEventId] as String?,
      createdAt:
          DateTime.parse(map[SessionReservationTable.colCreatedAt] as String),
      updatedAt:
          DateTime.parse(map[SessionReservationTable.colUpdatedAt] as String),
      memberName: map['member_name'] as String?,
      memberEmail: map['member_email'] as String?,
    );
  }

  /// Renvoie une copie avec la séance jointe attachée (lecture seule).
  /// Le service construit [session] à partir de colonnes aliasées, ce qui évite
  /// toute collision de noms (id, status, created_at) entre les deux tables.
  SessionReservation withSession(ActivitySession session) => SessionReservation(
        id: id,
        sessionId: sessionId,
        userId: userId,
        status: status,
        googleEventId: googleEventId,
        createdAt: createdAt,
        updatedAt: updatedAt,
        memberName: memberName,
        memberEmail: memberEmail,
        session: session,
      );
}
