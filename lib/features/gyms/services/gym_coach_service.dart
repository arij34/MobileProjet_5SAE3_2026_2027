import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/session/permissions.dart';
import '../../../core/session/session_manager.dart';
import '../../users/models/user.dart';
import '../../users/models/user_table.dart';
import '../../users/services/user_service.dart';
import '../../users/services/xp_service.dart';
import '../models/coach_enums.dart';
import '../models/gym.dart';
import '../models/gym_coach.dart';
import '../models/gym_coach_request.dart';
import '../models/gym_coach_tables.dart';
import '../models/gym_table.dart';
import 'gym_service.dart';

/// Un coach que le responsable peut inviter.
class CoachCandidate {
  final int id;
  final String name;
  final int gymCount; // 0 = coach libre
  const CoachCandidate(this.id, this.name, this.gymCount);
}

/// CRUD des coachs d'une salle + invitations / candidatures.
class GymCoachService {
  GymCoachService._();
  static final GymCoachService instance = GymCoachService._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  // ⚠ À ADAPTER à votre table users (voir user_table.dart) :
  // nom des colonnes rôle / statut et valeurs stockées pour "coach" / "actif".
  static const String _userRoleColumn = 'role';
  static const String _userStatusColumn = 'status';
  static const String _coachRoleValue = 'coach';
  static const String _activeStatusValue = 'active';

  static const String _coachSelect =
      'SELECT gc.*, '
      "(u.${UserTable.colFirstName} || ' ' || u.${UserTable.colLastName}) "
      'AS coach_name, g.${GymTable.colName} AS gym_name, '
      'g.${GymTable.colCity} AS gym_city '
      'FROM ${GymCoachTable.tableName} gc '
      'JOIN ${UserTable.tableName} u '
      'ON u.${UserTable.colId} = gc.${GymCoachTable.colCoachId} '
      'JOIN ${GymTable.tableName} g '
      'ON g.${GymTable.colId} = gc.${GymCoachTable.colGymId} ';

  static const String _requestSelect =
      'SELECT r.*, '
      "(u.${UserTable.colFirstName} || ' ' || u.${UserTable.colLastName}) "
      'AS coach_name, g.${GymTable.colName} AS gym_name, '
      'g.${GymTable.colCity} AS gym_city '
      'FROM ${GymCoachRequestTable.tableName} r '
      'JOIN ${UserTable.tableName} u '
      'ON u.${UserTable.colId} = r.${GymCoachRequestTable.colCoachId} '
      'JOIN ${GymTable.tableName} g '
      'ON g.${GymTable.colId} = r.${GymCoachRequestTable.colGymId} ';

  // ---------- Droits ----------

  /// Permission manageGymCoaches ET (admin ou propriétaire de la salle).
  bool canManage(Gym gym) =>
      Permissions.currentCan(Permission.manageGymCoaches) &&
      GymService.instance.isOwnerOrAdmin(gym);

  Future<Gym> _requireGymManager(int gymId) async {
    final gym = await GymService.instance.getById(gymId);
    if (gym == null) throw AuthException('Salle introuvable.');
    if (!canManage(gym)) throw AuthException('Action non autorisée.');
    return gym;
  }

  User _requireCoach() {
    final user = SessionManager.instance.currentUser;
    if (user == null || !Permissions.currentCan(Permission.applyAsCoach)) {
      throw AuthException('Action non autorisée.');
    }
    return user;
  }

  // ---------- Coachs d'une salle (CRUD) ----------

  Future<List<GymCoach>> getCoaches(int gymId) async {
    if (!Permissions.currentCan(Permission.viewGyms)) {
      throw AuthException('Accès non autorisé.');
    }
    final db = await _db;
    final rows = await db.rawQuery(
      '$_coachSelect WHERE gc.${GymCoachTable.colGymId} = ? '
      'ORDER BY coach_name COLLATE NOCASE',
      [gymId],
    );
    return rows.map(GymCoach.fromMap).toList();
  }

  Future<GymCoach?> _getCoachById(int id) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '$_coachSelect WHERE gc.${GymCoachTable.colId} = ? LIMIT 1',
      [id],
    );
    return rows.isEmpty ? null : GymCoach.fromMap(rows.first);
  }

  /// Modifie la fiche (spécialité, tarif, horaires, statut).
  /// Le coach et la salle ne changent jamais.
  Future<void> updateCoach(GymCoach c) async {
    final existing = c.id == null ? null : await _getCoachById(c.id!);
    if (existing == null) throw AuthException('Coach introuvable.');
    await _requireGymManager(existing.gymId);

    if (c.hourlyRate < 0) {
      throw AuthException('Le tarif doit être positif.');
    }
    final db = await _db;
    await db.update(
      GymCoachTable.tableName,
      {
        GymCoachTable.colSpecialty: c.specialty.trim(),
        GymCoachTable.colHourlyRate: c.hourlyRate,
        GymCoachTable.colAvailability: c.availability.trim(),
        GymCoachTable.colStatus: c.status.value,
      },
      where: '${GymCoachTable.colId} = ?',
      whereArgs: [existing.id],
    );
  }

  /// Le responsable retire un coach de sa salle.
  Future<void> removeCoach(int id) async {
    final existing = await _getCoachById(id);
    if (existing == null) return;
    await _requireGymManager(existing.gymId);
    final db = await _db;
    await db.delete(GymCoachTable.tableName,
        where: '${GymCoachTable.colId} = ?', whereArgs: [id]);
  }

  /// Le coach quitte une salle.
  Future<void> leaveGym(int id) async {
    final user = _requireCoach();
    final db = await _db;
    final n = await db.delete(
      GymCoachTable.tableName,
      where: '${GymCoachTable.colId} = ? AND ${GymCoachTable.colCoachId} = ?',
      whereArgs: [id, user.id],
    );
    if (n == 0) throw AuthException('Rattachement introuvable.');
  }

  // ---------- Côté coach : mes salles, salles disponibles ----------

  Future<List<GymCoach>> getMyGyms() async {
    final user = _requireCoach();
    final db = await _db;
    final rows = await db.rawQuery(
      '$_coachSelect WHERE gc.${GymCoachTable.colCoachId} = ? '
      'ORDER BY g.${GymTable.colName} COLLATE NOCASE',
      [user.id],
    );
    return rows.map(GymCoach.fromMap).toList();
  }

  /// Pour chaque salle : 'member' (déjà coach) ou 'pending' (demande en cours).
  Future<Map<int, String>> getLinkByGym() async {
    final user = _requireCoach();
    final db = await _db;
    final result = <int, String>{};
    final pend = await db.query(
      GymCoachRequestTable.tableName,
      columns: [GymCoachRequestTable.colGymId],
      where: '${GymCoachRequestTable.colCoachId} = ? AND '
          '${GymCoachRequestTable.colStatus} = ?',
      whereArgs: [user.id, CoachRequestStatus.pending.value],
    );
    for (final r in pend) {
      result[r[GymCoachRequestTable.colGymId] as int] = 'pending';
    }
    final mem = await db.query(
      GymCoachTable.tableName,
      columns: [GymCoachTable.colGymId],
      where: '${GymCoachTable.colCoachId} = ?',
      whereArgs: [user.id],
    );
    for (final r in mem) {
      result[r[GymCoachTable.colGymId] as int] = 'member';
    }
    return result;
  }

  // ---------- Recherche de coachs à inviter ----------

  Future<List<CoachCandidate>> searchCoaches(int gymId,
      {String search = ''}) async {
    await _requireGymManager(gymId);
    final q = search.trim();
    final name =
        "(u.${UserTable.colFirstName} || ' ' || u.${UserTable.colLastName})";
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT u.${UserTable.colId} AS id, $name AS name,
        (SELECT COUNT(*) FROM ${GymCoachTable.tableName} x
          WHERE x.${GymCoachTable.colCoachId} = u.${UserTable.colId})
          AS gym_count
      FROM ${UserTable.tableName} u
      WHERE u.$_userRoleColumn = ? AND u.$_userStatusColumn = ?
        AND u.${UserTable.colId} NOT IN (
          SELECT ${GymCoachTable.colCoachId} FROM ${GymCoachTable.tableName}
          WHERE ${GymCoachTable.colGymId} = ?)
        AND u.${UserTable.colId} NOT IN (
          SELECT ${GymCoachRequestTable.colCoachId}
          FROM ${GymCoachRequestTable.tableName}
          WHERE ${GymCoachRequestTable.colGymId} = ?
            AND ${GymCoachRequestTable.colStatus} = 'pending')
        ${q.isEmpty ? '' : 'AND $name LIKE ?'}
      ORDER BY $name COLLATE NOCASE
    ''', [
      _coachRoleValue,
      _activeStatusValue,
      gymId,
      gymId,
      if (q.isNotEmpty) '%$q%',
    ]);
    return rows
        .map((r) => CoachCandidate(
            r['id'] as int, (r['name'] as String?) ?? '', (r['gym_count'] as int?) ?? 0))
        .toList();
  }

  // ---------- Envoi des demandes ----------

  /// Le responsable invite un coach.
  Future<void> invite(
      {required int gymId, required int coachId, String message = ''}) async {
    await _requireGymManager(gymId);
    await _createRequest(
      gymId: gymId,
      coachId: coachId,
      by: CoachRequestInitiator.gym,
      message: message,
    );
  }

  /// Le coach postule à une salle ouverte.
  Future<void> applyToGym({required int gymId, String message = ''}) async {
    final user = _requireCoach();
    final gym = await GymService.instance.getById(gymId);
    if (gym == null) throw AuthException('Salle introuvable.');
    if (!gym.isOpen) {
      throw AuthException('Cette salle n\'accepte pas de demandes pour le moment.');
    }
    await _createRequest(
      gymId: gymId,
      coachId: user.id!,
      by: CoachRequestInitiator.coach,
      message: message,
    );
  }

  Future<void> _createRequest({
    required int gymId,
    required int coachId,
    required CoachRequestInitiator by,
    required String message,
  }) async {
    final db = await _db;

    final member = await db.query(
      GymCoachTable.tableName,
      where: '${GymCoachTable.colGymId} = ? AND ${GymCoachTable.colCoachId} = ?',
      whereArgs: [gymId, coachId],
      limit: 1,
    );
    if (member.isNotEmpty) {
      throw AuthException('Ce coach fait déjà partie de cette salle.');
    }
    final pending = await db.query(
      GymCoachRequestTable.tableName,
      where: '${GymCoachRequestTable.colGymId} = ? AND '
          '${GymCoachRequestTable.colCoachId} = ? AND '
          '${GymCoachRequestTable.colStatus} = ?',
      whereArgs: [gymId, coachId, CoachRequestStatus.pending.value],
      limit: 1,
    );
    if (pending.isNotEmpty) {
      throw AuthException('Une demande est déjà en attente.');
    }
    // Le compte invité doit être un coach actif.
    final coach = await UserService.instance.getById(coachId);
    if (coach == null || !Permissions.can(coach, Permission.applyAsCoach)) {
      throw AuthException('Ce compte n\'est pas un coach actif.');
    }

    await db.insert(
      GymCoachRequestTable.tableName,
      GymCoachRequest(
        gymId: gymId,
        coachId: coachId,
        initiatedBy: by,
        message: message.trim(),
        createdAt: DateTime.now(),
      ).toMap(),
    );
  }

  // ---------- Lecture des demandes ----------

  Future<List<GymCoachRequest>> getRequestsForGym(int gymId) async {
    await _requireGymManager(gymId);
    final db = await _db;
    final rows = await db.rawQuery(
      '$_requestSelect WHERE r.${GymCoachRequestTable.colGymId} = ? '
      'ORDER BY r.${GymCoachRequestTable.colCreatedAt} DESC',
      [gymId],
    );
    return rows.map(GymCoachRequest.fromMap).toList();
  }

  Future<List<GymCoachRequest>> getRequestsForCoach() async {
    final user = _requireCoach();
    final db = await _db;
    final rows = await db.rawQuery(
      '$_requestSelect WHERE r.${GymCoachRequestTable.colCoachId} = ? '
      'ORDER BY r.${GymCoachRequestTable.colCreatedAt} DESC',
      [user.id],
    );
    return rows.map(GymCoachRequest.fromMap).toList();
  }

  // ---------- Réponse aux demandes ----------

  Future<GymCoachRequest> _loadRequest(int id) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '$_requestSelect WHERE r.${GymCoachRequestTable.colId} = ? LIMIT 1',
      [id],
    );
    if (rows.isEmpty) throw AuthException('Demande introuvable.');
    return GymCoachRequest.fromMap(rows.first);
  }

  /// Seule la partie QUI N'A PAS envoyé la demande peut répondre.
  Future<void> _requireResponder(GymCoachRequest r) async {
    if (r.initiatedBy == CoachRequestInitiator.gym) {
      final user = _requireCoach(); // invitation : le coach répond
      if (user.id != r.coachId) throw AuthException('Action non autorisée.');
    } else {
      await _requireGymManager(r.gymId); // candidature : la salle répond
    }
  }

  Future<void> accept(int requestId) async {
    final r = await _loadRequest(requestId);
    await _requireResponder(r);
    if (!r.isPending) throw AuthException('Cette demande a déjà été traitée.');

    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        GymCoachRequestTable.tableName,
        {
          GymCoachRequestTable.colStatus: CoachRequestStatus.accepted.value,
          GymCoachRequestTable.colRespondedAt:
              DateTime.now().toIso8601String(),
        },
        where: '${GymCoachRequestTable.colId} = ?',
        whereArgs: [requestId],
      );
      await txn.insert(
        GymCoachTable.tableName,
        GymCoach(
          gymId: r.gymId,
          coachId: r.coachId,
          joinedAt: DateTime.now(),
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    });
    await _awardXp(r.coachId, r.gymId);
  }

  Future<void> reject(int requestId) async {
    final r = await _loadRequest(requestId);
    await _requireResponder(r);
    if (!r.isPending) throw AuthException('Cette demande a déjà été traitée.');
    await _setStatus(requestId, CoachRequestStatus.rejected);
  }

  /// L'initiateur annule sa propre demande tant qu'elle est en attente.
  Future<void> cancel(int requestId) async {
    final r = await _loadRequest(requestId);
    if (r.initiatedBy == CoachRequestInitiator.gym) {
      await _requireGymManager(r.gymId);
    } else {
      final user = _requireCoach();
      if (user.id != r.coachId) throw AuthException('Action non autorisée.');
    }
    if (!r.isPending) throw AuthException('Cette demande ne peut plus être annulée.');
    await _setStatus(requestId, CoachRequestStatus.cancelled);
  }

  Future<void> _setStatus(int id, CoachRequestStatus s) async {
    final db = await _db;
    await db.update(
      GymCoachRequestTable.tableName,
      {
        GymCoachRequestTable.colStatus: s.value,
        GymCoachRequestTable.colRespondedAt: DateTime.now().toIso8601String(),
      },
      where: '${GymCoachRequestTable.colId} = ? AND '
          '${GymCoachRequestTable.colStatus} = ?',
      whereArgs: [id, CoachRequestStatus.pending.value],
    );
  }

  // ---------- XP (voir guide du module Utilisateurs, section 7) ----------

  Future<void> _awardXp(int coachId, int gymId) async {
    try {
      final coach = await UserService.instance.getById(coachId);
      if (coach == null || !Permissions.can(coach, Permission.viewOwnProgress)) {
        return;
      }
      final gained = await XpService.instance.awardOnce(
        coachId,
        'coach_joined_gym_$gymId',
        10,
        'Intégration à une salle',
      );
      final me = SessionManager.instance.currentUser;
      if (gained > 0 && me?.id == coachId) {
        final fresh = await UserService.instance.getById(coachId);
        if (fresh != null) SessionManager.instance.currentUser = fresh;
      }
    } catch (_) {
      // L'XP ne doit jamais empêcher l'acceptation.
    }
  }
}
