import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/session/permissions.dart';
import '../../../core/session/session_manager.dart';
import '../../gyms/models/gym_table.dart';
import '../../gyms/services/gym_service.dart';
import '../../users/models/user.dart';
import '../../users/models/user_table.dart';
import '../../users/services/user_service.dart' show AuthException;
import '../models/activity_session.dart';
import '../models/activity_session_table.dart';
import '../models/activity_table.dart';
import '../models/reservation_status.dart';
import '../models/session_reservation.dart';
import '../models/session_reservation_table.dart';

/// Résultat d'une réservation : la réservation créée + la séance concernée.
class BookingOutcome {
  final SessionReservation reservation;
  final ActivitySession session;
  const BookingOutcome(this.reservation, this.session);

  bool get waitlisted => reservation.isWaitlisted;
}

/// Résultat d'une annulation : la réservation annulée, la séance, et le cas
/// échéant l'adhérent de la liste d'attente qui vient d'être promu (pour le
/// prévenir par email).
class CancellationOutcome {
  final SessionReservation cancelled;
  final ActivitySession session;
  final SessionReservation? promoted;
  const CancellationOutcome(this.cancelled, this.session, this.promoted);
}

/// Gestion intelligente des réservations.
///
/// Toutes les règles métier sont vérifiées ici, avant chaque opération :
///  - un adhérent ne peut pas réserver deux fois la même séance ;
///  - au-delà de la capacité, l'adhérent passe en liste d'attente ;
///  - le nombre de places restantes est toujours recalculé depuis la base ;
///  - à l'annulation d'une place confirmée, le premier de la file est promu ;
///  - les statuts sont mis à jour de façon cohérente (dans une transaction).
class ReservationService {
  ReservationService._();
  static final ReservationService instance = ReservationService._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  static const String _table = SessionReservationTable.tableName;

  // ---------- Droits ----------

  User _requireMember() {
    final user = SessionManager.instance.currentUser;
    if (user == null || !Permissions.currentCan(Permission.bookSession)) {
      throw AuthException('Action non autorisée.');
    }
    return user;
  }

  // ---------- Côté adhérent ----------

  /// Réserve une séance. Si la séance est complète, l'adhérent est placé en
  /// liste d'attente. Renvoie le résultat (confirmé ou en attente).
  Future<BookingOutcome> book(int sessionId) async {
    final user = _requireMember();
    final session = await _loadSession(sessionId);
    if (session.isPast) {
      throw AuthException('Cette séance est déjà passée.');
    }

    final db = await _db;
    final reservation = await db.transaction<SessionReservation>((txn) async {
      // 1) Interdire une deuxième réservation active de la même séance.
      final existing = await txn.query(
        _table,
        where: '${SessionReservationTable.colSessionId} = ? AND '
            '${SessionReservationTable.colUserId} = ? AND '
            '${SessionReservationTable.colStatus} IN (?, ?)',
        whereArgs: [
          sessionId,
          user.id,
          ReservationStatus.confirmed.value,
          ReservationStatus.waitlisted.value,
        ],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw AuthException('Vous avez déjà réservé cette séance.');
      }

      // 2) Recompter les confirmés DANS la transaction (places restantes).
      final confirmed = await _countStatus(
          txn, sessionId, ReservationStatus.confirmed);
      final status = confirmed < session.capacityMax
          ? ReservationStatus.confirmed
          : ReservationStatus.waitlisted;

      // 3) Créer la réservation avec le bon statut.
      final now = DateTime.now();
      final toSave = SessionReservation(
        sessionId: sessionId,
        userId: user.id!,
        status: status,
        createdAt: now,
        updatedAt: now,
      );
      final id = await txn.insert(_table, toSave.toMap());
      return SessionReservation(
        id: id,
        sessionId: sessionId,
        userId: user.id!,
        status: status,
        createdAt: now,
        updatedAt: now,
      );
    });

    // Séance rechargée pour un comptage à jour (places restantes).
    final fresh = await _loadSession(sessionId);
    return BookingOutcome(reservation, fresh);
  }

  /// Annule une réservation de l'adhérent connecté. Si une place confirmée se
  /// libère, promeut automatiquement le premier adhérent de la liste d'attente.
  Future<CancellationOutcome> cancel(int reservationId) async {
    final user = _requireMember();
    final db = await _db;

    final current = await _loadReservation(reservationId);
    if (current.userId != user.id) {
      throw AuthException('Action non autorisée.');
    }
    if (!current.isActive) {
      throw AuthException('Cette réservation est déjà annulée.');
    }
    final session = await _loadSession(current.sessionId);
    if (session.isPast) {
      throw AuthException('Cette séance est déjà passée.');
    }

    final freedConfirmed = current.isConfirmed;

    final promoted = await db.transaction<SessionReservation?>((txn) async {
      final now = DateTime.now().toIso8601String();
      // 1) Annuler la réservation (seulement si encore active).
      final updated = await txn.update(
        _table,
        {
          SessionReservationTable.colStatus: ReservationStatus.cancelled.value,
          SessionReservationTable.colUpdatedAt: now,
        },
        where: '${SessionReservationTable.colId} = ? AND '
            '${SessionReservationTable.colStatus} IN (?, ?)',
        whereArgs: [
          reservationId,
          ReservationStatus.confirmed.value,
          ReservationStatus.waitlisted.value,
        ],
      );
      if (updated == 0) {
        throw AuthException('Cette réservation est déjà annulée.');
      }

      // 2) Une place confirmée s'est-elle libérée ? Promouvoir le 1er en file.
      if (!freedConfirmed) return null;
      final confirmed =
          await _countStatus(txn, current.sessionId, ReservationStatus.confirmed);
      if (confirmed >= session.capacityMax) return null;

      final waiting = await txn.query(
        _table,
        where: '${SessionReservationTable.colSessionId} = ? AND '
            '${SessionReservationTable.colStatus} = ?',
        whereArgs: [current.sessionId, ReservationStatus.waitlisted.value],
        orderBy: '${SessionReservationTable.colCreatedAt} ASC, '
            '${SessionReservationTable.colId} ASC',
        limit: 1,
      );
      if (waiting.isEmpty) return null;

      final first = SessionReservation.fromMap(waiting.first);
      await txn.update(
        _table,
        {
          SessionReservationTable.colStatus: ReservationStatus.confirmed.value,
          SessionReservationTable.colUpdatedAt: now,
        },
        where: '${SessionReservationTable.colId} = ?',
        whereArgs: [first.id],
      );
      // Recharger avec le nom et l'email du promu (pour la notification).
      return _loadReservationWithMember(txn, first.id!);
    });

    final cancelled = await _loadReservation(reservationId);
    final fresh = await _loadSession(current.sessionId);
    return CancellationOutcome(cancelled, fresh, promoted);
  }

  /// Historique complet des réservations de l'adhérent (séance jointe).
  Future<List<SessionReservation>> getMine() async {
    final user = _requireMember();
    final db = await _db;
    final rows = await db.rawQuery(_mineSelect, [user.id]);
    return rows.map(_reservationWithSession).toList();
  }

  /// Statut actif (confirmé / en attente) de l'adhérent pour chaque séance,
  /// afin d'adapter le bouton « Réserver » dans la liste des séances.
  Future<Map<int, ReservationStatus>> getMyStatusBySession() async {
    final user = SessionManager.instance.currentUser;
    if (user == null || !Permissions.currentCan(Permission.bookSession)) {
      return {};
    }
    final db = await _db;
    final rows = await db.query(
      _table,
      columns: [
        SessionReservationTable.colSessionId,
        SessionReservationTable.colStatus,
      ],
      where: '${SessionReservationTable.colUserId} = ? AND '
          '${SessionReservationTable.colStatus} IN (?, ?)',
      whereArgs: [
        user.id,
        ReservationStatus.confirmed.value,
        ReservationStatus.waitlisted.value,
      ],
    );
    return {
      for (final r in rows)
        r[SessionReservationTable.colSessionId] as int:
            ReservationStatus.fromValue(
                r[SessionReservationTable.colStatus] as String?),
    };
  }

  /// Enregistre l'id de l'évènement Google Agenda créé pour une réservation
  /// (évite les doublons : voir CalendarService).
  Future<void> setGoogleEventId(int reservationId, String eventId) async {
    final db = await _db;
    await db.update(
      _table,
      {SessionReservationTable.colGoogleEventId: eventId},
      where: '${SessionReservationTable.colId} = ?',
      whereArgs: [reservationId],
    );
  }

  // ---------- Côté responsable ----------

  /// Inscriptions d'une séance (confirmés d'abord, puis file d'attente dans
  /// l'ordre d'arrivée). Réservé au responsable propriétaire de la salle.
  Future<List<SessionReservation>> getForSession(int sessionId) async {
    final session = await _loadSession(sessionId);
    final gym = session.gymId == null
        ? null
        : await GymService.instance.getById(session.gymId!);
    if (gym == null ||
        !Permissions.currentCan(Permission.manageActivities) ||
        !GymService.instance.isOwnerOrAdmin(gym)) {
      throw AuthException('Action non autorisée.');
    }

    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT r.*, '
      "(u.${UserTable.colFirstName} || ' ' || u.${UserTable.colLastName}) "
      'AS member_name, u.${UserTable.colEmail} AS member_email '
      'FROM $_table r '
      'JOIN ${UserTable.tableName} u '
      'ON u.${UserTable.colId} = r.${SessionReservationTable.colUserId} '
      'WHERE r.${SessionReservationTable.colSessionId} = ? AND '
      'r.${SessionReservationTable.colStatus} IN (?, ?) '
      "ORDER BY CASE r.${SessionReservationTable.colStatus} "
      "WHEN '${ReservationStatus.confirmed.value}' THEN 0 ELSE 1 END, "
      'r.${SessionReservationTable.colCreatedAt} ASC',
      [
        sessionId,
        ReservationStatus.confirmed.value,
        ReservationStatus.waitlisted.value,
      ],
    );
    return rows.map(SessionReservation.fromMap).toList();
  }

  // ---------- Interne ----------

  Future<int> _countStatus(
      DatabaseExecutor txn, int sessionId, ReservationStatus status) async {
    final rows = await txn.rawQuery(
      'SELECT COUNT(*) AS c FROM $_table '
      'WHERE ${SessionReservationTable.colSessionId} = ? AND '
      '${SessionReservationTable.colStatus} = ?',
      [sessionId, status.value],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<ActivitySession> _loadSession(int id) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '${_sessionSelect}WHERE s.${ActivitySessionTable.colId} = ? LIMIT 1',
      [id],
    );
    if (rows.isEmpty) throw AuthException('Séance introuvable.');
    return ActivitySession.fromMap(rows.first);
  }

  Future<SessionReservation> _loadReservation(int id) async {
    final db = await _db;
    final rows = await db.query(
      _table,
      where: '${SessionReservationTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw AuthException('Réservation introuvable.');
    return SessionReservation.fromMap(rows.first);
  }

  Future<SessionReservation> _loadReservationWithMember(
      DatabaseExecutor txn, int id) async {
    final rows = await txn.rawQuery(
      'SELECT r.*, '
      "(u.${UserTable.colFirstName} || ' ' || u.${UserTable.colLastName}) "
      'AS member_name, u.${UserTable.colEmail} AS member_email '
      'FROM $_table r '
      'JOIN ${UserTable.tableName} u '
      'ON u.${UserTable.colId} = r.${SessionReservationTable.colUserId} '
      'WHERE r.${SessionReservationTable.colId} = ? LIMIT 1',
      [id],
    );
    return SessionReservation.fromMap(rows.first);
  }

  /// SELECT des séances (confirmés / file comptés), sans clause WHERE.
  static String get _sessionSelect {
    final confirmed = ReservationStatus.confirmed.value;
    final waitlisted = ReservationStatus.waitlisted.value;
    return 'SELECT s.*, '
        'a.${ActivityTable.colName} AS activity_name, '
        'a.${ActivityTable.colCategory} AS activity_category, '
        'a.${ActivityTable.colGymId} AS gym_id, '
        'g.${GymTable.colName} AS gym_name, '
        "(uc.${UserTable.colFirstName} || ' ' || uc.${UserTable.colLastName}) "
        'AS coach_name, '
        '(SELECT COUNT(*) FROM $_table r '
        'WHERE r.${SessionReservationTable.colSessionId} = s.${ActivitySessionTable.colId} '
        "AND r.${SessionReservationTable.colStatus} = '$confirmed') AS confirmed_count, "
        '(SELECT COUNT(*) FROM $_table r '
        'WHERE r.${SessionReservationTable.colSessionId} = s.${ActivitySessionTable.colId} '
        "AND r.${SessionReservationTable.colStatus} = '$waitlisted') AS waitlist_count "
        'FROM ${ActivitySessionTable.tableName} s '
        'JOIN ${ActivityTable.tableName} a '
        'ON a.${ActivityTable.colId} = s.${ActivitySessionTable.colActivityId} '
        'JOIN ${GymTable.tableName} g '
        'ON g.${GymTable.colId} = a.${ActivityTable.colGymId} '
        'LEFT JOIN ${UserTable.tableName} uc '
        'ON uc.${UserTable.colId} = s.${ActivitySessionTable.colCoachId} ';
  }

  /// SELECT de l'historique de l'adhérent : réservation (r.*) + séance aliasée.
  static String get _mineSelect {
    final confirmed = ReservationStatus.confirmed.value;
    final waitlisted = ReservationStatus.waitlisted.value;
    return 'SELECT r.*, '
        's.${ActivitySessionTable.colId} AS s_id, '
        's.${ActivitySessionTable.colActivityId} AS s_activity_id, '
        's.${ActivitySessionTable.colCoachId} AS s_coach_id, '
        's.${ActivitySessionTable.colStartAt} AS start_at, '
        's.${ActivitySessionTable.colDurationMin} AS s_duration_min, '
        's.${ActivitySessionTable.colCapacityMax} AS s_capacity_max, '
        's.${ActivitySessionTable.colCreatedAt} AS s_created_at, '
        'a.${ActivityTable.colName} AS activity_name, '
        'a.${ActivityTable.colCategory} AS activity_category, '
        'a.${ActivityTable.colGymId} AS gym_id, '
        'g.${GymTable.colName} AS gym_name, '
        "(uc.${UserTable.colFirstName} || ' ' || uc.${UserTable.colLastName}) "
        'AS coach_name, '
        '(SELECT COUNT(*) FROM $_table rr '
        'WHERE rr.${SessionReservationTable.colSessionId} = s.${ActivitySessionTable.colId} '
        "AND rr.${SessionReservationTable.colStatus} = '$confirmed') AS confirmed_count, "
        '(SELECT COUNT(*) FROM $_table rr '
        'WHERE rr.${SessionReservationTable.colSessionId} = s.${ActivitySessionTable.colId} '
        "AND rr.${SessionReservationTable.colStatus} = '$waitlisted') AS waitlist_count "
        'FROM $_table r '
        'JOIN ${ActivitySessionTable.tableName} s '
        'ON s.${ActivitySessionTable.colId} = r.${SessionReservationTable.colSessionId} '
        'JOIN ${ActivityTable.tableName} a '
        'ON a.${ActivityTable.colId} = s.${ActivitySessionTable.colActivityId} '
        'JOIN ${GymTable.tableName} g '
        'ON g.${GymTable.colId} = a.${ActivityTable.colGymId} '
        'LEFT JOIN ${UserTable.tableName} uc '
        'ON uc.${UserTable.colId} = s.${ActivitySessionTable.colCoachId} '
        'WHERE r.${SessionReservationTable.colUserId} = ? '
        'ORDER BY s.${ActivitySessionTable.colStartAt} DESC';
  }

  /// Reconstruit une réservation + sa séance à partir d'une ligne de
  /// [_mineSelect] (colonnes de séance aliasées pour éviter les collisions).
  SessionReservation _reservationWithSession(Map<String, dynamic> row) {
    final res = SessionReservation.fromMap(row);
    final session = ActivitySession.fromMap({
      ActivitySessionTable.colId: row['s_id'],
      ActivitySessionTable.colActivityId: row['s_activity_id'],
      ActivitySessionTable.colCoachId: row['s_coach_id'],
      ActivitySessionTable.colStartAt: row['start_at'],
      ActivitySessionTable.colDurationMin: row['s_duration_min'],
      ActivitySessionTable.colCapacityMax: row['s_capacity_max'],
      ActivitySessionTable.colCreatedAt: row['s_created_at'],
      'activity_name': row['activity_name'],
      'activity_category': row['activity_category'],
      'gym_id': row['gym_id'],
      'gym_name': row['gym_name'],
      'coach_name': row['coach_name'],
      'confirmed_count': row['confirmed_count'],
      'waitlist_count': row['waitlist_count'],
    });
    return res.withSession(session);
  }
}
