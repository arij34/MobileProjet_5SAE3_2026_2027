import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/session/permissions.dart';
import '../../gyms/models/gym_coach_tables.dart';
import '../../gyms/models/gym_table.dart';
import '../../gyms/services/gym_service.dart';
import '../../users/models/user_table.dart';
import '../../users/services/user_service.dart' show AuthException;
import '../models/activity_session.dart';
import '../models/activity_session_table.dart';
import '../models/activity_table.dart';
import '../models/reservation_status.dart';
import '../models/session_reservation_table.dart';

/// CRUD des séances (le « planning ») + comptage des places et de la file.
class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  static const String _table = ActivitySessionTable.tableName;
  static const String _res = SessionReservationTable.tableName;

  /// Séance + nom de l'activité + salle + coach + nombre de confirmés / en file.
  static String get _select {
    final confirmed = ReservationStatus.confirmed.value;
    final waitlisted = ReservationStatus.waitlisted.value;
    return 'SELECT s.*, '
        'a.${ActivityTable.colName} AS activity_name, '
        'a.${ActivityTable.colCategory} AS activity_category, '
        'a.${ActivityTable.colGymId} AS gym_id, '
        'g.${GymTable.colName} AS gym_name, '
        "(u.${UserTable.colFirstName} || ' ' || u.${UserTable.colLastName}) "
        'AS coach_name, '
        '(SELECT COUNT(*) FROM $_res r '
        'WHERE r.${SessionReservationTable.colSessionId} = s.${ActivitySessionTable.colId} '
        "AND r.${SessionReservationTable.colStatus} = '$confirmed') AS confirmed_count, "
        '(SELECT COUNT(*) FROM $_res r '
        'WHERE r.${SessionReservationTable.colSessionId} = s.${ActivitySessionTable.colId} '
        "AND r.${SessionReservationTable.colStatus} = '$waitlisted') AS waitlist_count "
        'FROM $_table s '
        'JOIN ${ActivityTable.tableName} a '
        'ON a.${ActivityTable.colId} = s.${ActivitySessionTable.colActivityId} '
        'JOIN ${GymTable.tableName} g '
        'ON g.${GymTable.colId} = a.${ActivityTable.colGymId} '
        'LEFT JOIN ${UserTable.tableName} u '
        'ON u.${UserTable.colId} = s.${ActivitySessionTable.colCoachId} ';
  }

  // ---------- Droits ----------

  void _requireViewer() {
    if (!Permissions.currentCan(Permission.viewActivities)) {
      throw AuthException('Accès non autorisé.');
    }
  }

  /// Vérifie que le responsable connecté gère bien la salle de cette activité.
  /// Renvoie l'id de la salle.
  Future<int> _requireManagerForActivity(int activityId) async {
    final db = await _db;
    final rows = await db.query(
      ActivityTable.tableName,
      columns: [ActivityTable.colGymId],
      where: '${ActivityTable.colId} = ?',
      whereArgs: [activityId],
      limit: 1,
    );
    if (rows.isEmpty) throw AuthException('Activité introuvable.');
    final gymId = rows.first[ActivityTable.colGymId] as int;
    final gym = await GymService.instance.getById(gymId);
    if (gym == null ||
        !Permissions.currentCan(Permission.manageActivities) ||
        !GymService.instance.isOwnerOrAdmin(gym)) {
      throw AuthException('Action non autorisée.');
    }
    return gymId;
  }

  // ---------- Lecture ----------

  Future<ActivitySession?> getById(int id) async {
    _requireViewer();
    final db = await _db;
    final rows = await db.rawQuery(
      '$_select WHERE s.${ActivitySessionTable.colId} = ? LIMIT 1',
      [id],
    );
    return rows.isEmpty ? null : ActivitySession.fromMap(rows.first);
  }

  /// Planning d'une salle (toutes les séances, à venir d'abord).
  Future<List<ActivitySession>> getForGym(int gymId,
      {bool upcomingOnly = false}) async {
    _requireViewer();
    final where = <String>['a.${ActivityTable.colGymId} = ?'];
    final args = <Object?>[gymId];
    if (upcomingOnly) {
      where.add('s.${ActivitySessionTable.colStartAt} >= ?');
      args.add(DateTime.now().toIso8601String());
    }
    final db = await _db;
    final rows = await db.rawQuery(
      '$_select WHERE ${where.join(' AND ')} '
      'ORDER BY s.${ActivitySessionTable.colStartAt} ASC',
      args,
    );
    return rows.map(ActivitySession.fromMap).toList();
  }

  /// Séances d'une activité donnée.
  Future<List<ActivitySession>> getForActivity(int activityId) async {
    _requireViewer();
    final db = await _db;
    final rows = await db.rawQuery(
      '$_select WHERE s.${ActivitySessionTable.colActivityId} = ? '
      'ORDER BY s.${ActivitySessionTable.colStartAt} ASC',
      [activityId],
    );
    return rows.map(ActivitySession.fromMap).toList();
  }

  /// Séances à venir, proposées aux adhérents (toutes salles confondues).
  Future<List<ActivitySession>> getAvailableForMembers({String search = ''}) async {
    _requireViewer();
    final where = <String>['s.${ActivitySessionTable.colStartAt} >= ?'];
    final args = <Object?>[DateTime.now().toIso8601String()];
    final q = search.trim();
    if (q.isNotEmpty) {
      where.add('(a.${ActivityTable.colName} LIKE ? OR '
          'g.${GymTable.colName} LIKE ? OR '
          'a.${ActivityTable.colCategory} LIKE ?)');
      args.addAll(['%$q%', '%$q%', '%$q%']);
    }
    final db = await _db;
    final rows = await db.rawQuery(
      '$_select WHERE ${where.join(' AND ')} '
      'ORDER BY s.${ActivitySessionTable.colStartAt} ASC',
      args,
    );
    return rows.map(ActivitySession.fromMap).toList();
  }

  // ---------- Création / modification / suppression ----------

  Future<ActivitySession> create(ActivitySession session) async {
    await _requireManagerForActivity(session.activityId);
    final clean = await _validated(session);
    final db = await _db;
    final id = await db.insert(_table, clean.toMap());
    return clean.copyWith(id: id);
  }

  Future<void> update(ActivitySession session) async {
    if (session.id == null) throw AuthException('Séance introuvable.');
    final existing = await getById(session.id!);
    if (existing == null) throw AuthException('Séance introuvable.');
    await _requireManagerForActivity(existing.activityId);

    // L'activité d'une séance ne change pas après création.
    final clean = await _validated(
      session.copyWith(activityId: existing.activityId),
      excludeConfirmed: existing.confirmedCount,
    );
    final map = clean.toMap()
      ..remove(ActivitySessionTable.colId)
      ..remove(ActivitySessionTable.colActivityId)
      ..remove(ActivitySessionTable.colCreatedAt);
    final db = await _db;
    await db.update(
      _table,
      map,
      where: '${ActivitySessionTable.colId} = ?',
      whereArgs: [existing.id],
    );
  }

  Future<void> delete(int id) async {
    final existing = await getById(id);
    if (existing == null) return;
    await _requireManagerForActivity(existing.activityId);
    final db = await _db;
    await db.delete(
      _table,
      where: '${ActivitySessionTable.colId} = ?',
      whereArgs: [id],
    );
  }

  // ---------- Interne ----------

  /// Règles métier : créneau futur, capacité valide, coach rattaché à la salle.
  /// [excludeConfirmed] : lors d'une modification, on refuse de descendre la
  /// capacité en dessous du nombre de places déjà confirmées.
  Future<ActivitySession> _validated(ActivitySession s,
      {int excludeConfirmed = 0}) async {
    if (s.capacityMax <= 0) {
      throw AuthException('La capacité doit être d\'au moins 1 place.');
    }
    if (s.durationMin <= 0 || s.durationMin > 600) {
      throw AuthException('La durée doit être comprise entre 1 et 600 minutes.');
    }
    if (s.startAt.isBefore(DateTime.now())) {
      throw AuthException('La date doit être dans le futur.');
    }
    if (excludeConfirmed > s.capacityMax) {
      throw AuthException(
          'Capacité trop basse : $excludeConfirmed places déjà confirmées.');
    }

    // Si un coach est associé, il doit faire partie de la salle de l'activité.
    if (s.coachId != null) {
      final db = await _db;
      final gymRows = await db.query(
        ActivityTable.tableName,
        columns: [ActivityTable.colGymId],
        where: '${ActivityTable.colId} = ?',
        whereArgs: [s.activityId],
        limit: 1,
      );
      if (gymRows.isEmpty) throw AuthException('Activité introuvable.');
      final gymId = gymRows.first[ActivityTable.colGymId] as int;
      final coachRows = await db.query(
        GymCoachTable.tableName,
        columns: [GymCoachTable.colId],
        where: '${GymCoachTable.colGymId} = ? AND ${GymCoachTable.colCoachId} = ?',
        whereArgs: [gymId, s.coachId],
        limit: 1,
      );
      if (coachRows.isEmpty) {
        throw AuthException('Ce coach ne fait pas partie de cette salle.');
      }
    }
    return s;
  }
}
