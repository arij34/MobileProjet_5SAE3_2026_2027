import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/session/permissions.dart';
import '../../../core/session/session_manager.dart';
import '../../users/models/user_table.dart';
import '../../users/models/user.dart';
import '../../users/models/user_role.dart';
import '../../notifications/models/notification_type.dart';
import '../../notifications/services/notification_service.dart';
import '../models/challenge.dart';
import '../models/challenge_status.dart';
import '../models/challenge_table.dart';
import '../models/challenge_task.dart';
import '../models/challenge_task_log.dart';

/// Erreur métier du module Challenges (message prêt à afficher, comme AuthException).
class ChallengeException implements Exception {
  final String message;
  const ChallengeException(this.message);

  @override
  String toString() => message;
}

class ChallengeService {
  ChallengeService._()
    : _database = (() => DatabaseHelper.instance.database),
      _notifications = NotificationService.instance,
      _now = DateTime.now;
  @visibleForTesting
  ChallengeService.forDatabase(
    Future<Database> Function() database,
    NotificationService notifications, {
    DateTime Function()? now,
  }) : _database = database,
       _notifications = notifications,
       _now = now ?? DateTime.now;
  static final ChallengeService instance = ChallengeService._();

  final Future<Database> Function() _database;
  final NotificationService _notifications;
  final DateTime Function() _now;
  static const int minTitleLength = 3;
  static const int maxTasks = 20;
  static const int maxChallengeXp = 500;
  static const int maxTaskXp = 100;

  Future<Database> get _db => _database();

  static ChallengeStatus initialStatus(User user) => user.role == UserRole.coach
      ? ChallengeStatus.pending
      : ChallengeStatus.active;

  static bool canViewChallenge(User user, Challenge challenge) =>
      Permissions.can(user, Permission.viewChallenges) &&
      (challenge.status == ChallengeStatus.active ||
          user.role == UserRole.admin ||
          (user.role == UserRole.coach &&
              user.id != null &&
              user.id == challenge.createdBy));

  static bool needsResubmission(User user, ChallengeStatus status) =>
      user.role == UserRole.coach &&
      (status == ChallengeStatus.pending || status == ChallengeStatus.rejected);

  static bool coachEditLocked(User? user, Challenge challenge, DateTime now) =>
      user?.role == UserRole.coach &&
      challenge.timeStateAt(now) != ChallengeTimeState.upcoming;

  static void validateReview(
    Challenge challenge, {
    String? reason,
    DateTime? now,
  }) {
    if (reason != null && reason.trim().length < 5) {
      throw const ChallengeException(
        'Le motif doit contenir au moins 5 caractères',
      );
    }
    if (challenge.status != ChallengeStatus.pending) {
      throw const ChallengeException(
        'Seul un challenge en attente peut être évalué',
      );
    }
    if (reason == null &&
        challenge.timeStateAt(now ?? DateTime.now()) ==
            ChallengeTimeState.ended) {
      throw const ChallengeException(
        'La date de fin est dépassée, le coach doit modifier les dates',
      );
    }
  }

  /// Vérifie les règles métier. Lève une [ChallengeException] au premier problème.
  /// [now] sert uniquement à rendre le test de la date de début possible.
  static void validate(
    Challenge challenge,
    List<ChallengeTask> tasks, {
    DateTime? now,
    bool validateStartDate = true,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);

    if (challenge.title.trim().length < minTitleLength) {
      throw const ChallengeException(
        'Le titre doit contenir au moins $minTitleLength caractères',
      );
    }
    if (challenge.xpReward < 0 || challenge.xpReward > maxChallengeXp) {
      throw const ChallengeException(
        'Les XP du challenge doivent être entre 0 et $maxChallengeXp',
      );
    }
    if (!challenge.endDate.isAfter(challenge.startDate)) {
      throw const ChallengeException(
        'La date de fin doit être après la date de début',
      );
    }
    if (validateStartDate && challenge.startDate.isBefore(today)) {
      throw const ChallengeException(
        'La date de début ne peut pas être dans le passé',
      );
    }
    if (tasks.isEmpty) {
      throw const ChallengeException('Ajoutez au moins une tâche');
    }
    if (tasks.length > maxTasks) {
      throw const ChallengeException(
        'Un challenge ne peut pas dépasser '
        '$maxTasks tâches',
      );
    }
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      final n = i + 1;
      final dates = task.scheduledDates.map(ChallengeTaskLog.dateKey).toList();
      if (dates.toSet().length != dates.length ||
          dates.any(
            (date) =>
                date.compareTo(ChallengeTaskLog.dateKey(challenge.startDate)) <
                    0 ||
                date.compareTo(ChallengeTaskLog.dateKey(challenge.endDate)) > 0,
          )) {
        throw ChallengeException(
          'Tâche $n : les dates doivent être uniques et comprises dans le challenge',
        );
      }
      if (task.title.trim().isEmpty) {
        throw ChallengeException('Tâche $n : le titre est obligatoire');
      }
      if (!(task.targetValue > 0)) {
        throw ChallengeException(
          'Tâche $n : l\'objectif doit être supérieur à 0',
        );
      }
      if (task.xpReward < 0 || task.xpReward > maxTaskXp) {
        throw ChallengeException(
          'Tâche $n : les XP doivent être entre 0 et $maxTaskXp',
        );
      }
    }
  }

  /// Crée un challenge et toutes ses tâches dans UNE transaction.
  /// Le créateur vient toujours de la session, jamais de l'interface.
  Future<Challenge> createChallenge(
    Challenge challenge,
    List<ChallengeTask> tasks,
  ) async {
    final user = SessionManager.instance.currentUser;
    if (user == null || !Permissions.can(user, Permission.manageChallenges)) {
      throw const ChallengeException(
        'Vous n\'avez pas le droit de créer un challenge',
      );
    }
    final userId = user.id;
    if (userId == null) {
      throw const ChallengeException('Session invalide, reconnectez-vous');
    }

    validate(challenge, tasks);

    final now = DateTime.now();
    final toSave = challenge.copyWith(
      title: challenge.title.trim(),
      description: challenge.description.trim(),
      createdBy: userId,
      createdAt: now,
      updatedAt: now,
      status: initialStatus(user),
      rejectionReason: null,
      reviewedBy: user.role == UserRole.admin ? userId : null,
      reviewedAt: user.role == UserRole.admin ? now : null,
    );
    // Réindexe 0..n-1 quel que soit l'ordre d'origine.
    final ordered = [
      for (var i = 0; i < tasks.length; i++)
        tasks[i].copyWith(title: tasks[i].title.trim(), orderIndex: i),
    ];

    final db = await _db;
    final id = await db.transaction((txn) async {
      final map = toSave.toMap()..remove(ChallengeTable.colId);
      final challengeId = await txn.insert(ChallengeTable.tableName, map);
      for (final task in ordered) {
        final taskMap = task.copyWith(challengeId: challengeId).toMap()
          ..remove(ChallengeTaskTable.colId);
        await txn.insert(ChallengeTaskTable.tableName, taskMap);
      }
      if (user.role == UserRole.coach) {
        await _notifyAdmins(txn, user, toSave, challengeId, now);
      } else {
        await _notifyMembers(txn, userId, toSave, challengeId, now);
      }
      return challengeId;
    });

    final saved = await getChallengeById(id);
    if (saved == null) {
      throw const ChallengeException(
        'Le challenge n\'a pas pu être enregistré',
      );
    }
    return saved;
  }

  /// Modifie un challenge existant sans accepter ses données d'audit depuis l'UI.
  Future<Challenge> updateChallenge(
    Challenge challenge,
    List<ChallengeTask> tasks,
  ) async {
    final id = challenge.id;
    if (id == null) {
      throw const ChallengeException('Challenge introuvable');
    }

    final existing = await getChallengeById(id);
    if (existing == null) {
      throw const ChallengeException('Challenge introuvable');
    }
    if (!Permissions.currentCanModifyChallenge(existing.createdBy)) {
      throw const ChallengeException(
        'Vous n\'avez pas le droit de modifier ce challenge',
      );
    }
    if (existing.status == ChallengeStatus.cancelled) {
      throw const ChallengeException(
        'Un challenge annulé ne peut pas être modifié',
      );
    }
    if (coachEditLocked(
      SessionManager.instance.currentUser,
      existing,
      _now(),
    )) {
      throw const ChallengeException(
        'Un coach ne peut plus modifier un challenge dès sa date de début',
      );
    }

    final participants = await countParticipants(id);
    final tasksChanged = !_sameTasks(existing.tasks, tasks);
    final startDateChanged = !challenge.startDate.isAtSameMomentAs(
      existing.startDate,
    );

    if (participants > 0) {
      if (tasksChanged) {
        throw const ChallengeException(
          'Les tâches ne peuvent plus être modifiées après la première inscription',
        );
      }
      if (startDateChanged ||
          challenge.difficulty != existing.difficulty ||
          challenge.xpReward != existing.xpReward) {
        throw const ChallengeException(
          'Après une inscription, seuls le titre, la description, '
          'l’image et la prolongation de la date de fin sont modifiables',
        );
      }
      if (challenge.endDate.isBefore(existing.endDate)) {
        throw const ChallengeException(
          'La date de fin ne peut pas être raccourcie après une inscription',
        );
      }
    }

    validate(challenge, tasks, validateStartDate: startDateChanged);

    final now = DateTime.now();
    final map = challenge.toMap()
      ..remove(ChallengeTable.colId)
      ..[ChallengeTable.colTitle] = challenge.title.trim()
      ..[ChallengeTable.colDescription] = challenge.description.trim()
      ..[ChallengeTable.colCreatedBy] = existing.createdBy
      ..[ChallengeTable.colCreatedAt] = existing.createdAt.toIso8601String()
      ..[ChallengeTable.colStatus] = existing.status.value
      ..[ChallengeTable.colRejectionReason] = existing.rejectionReason
      ..[ChallengeTable.colReviewedBy] = existing.reviewedBy
      ..[ChallengeTable.colReviewedAt] = existing.reviewedAt?.toIso8601String()
      ..[ChallengeTable.colUpdatedAt] = now.toIso8601String();
    final user = SessionManager.instance.currentUser;
    if (user != null && needsResubmission(user, existing.status)) {
      map[ChallengeTable.colStatus] = ChallengeStatus.pending.value;
      map[ChallengeTable.colRejectionReason] = null;
      map[ChallengeTable.colReviewedBy] = null;
      map[ChallengeTable.colReviewedAt] = null;
    }

    final db = await _db;
    await db.transaction((txn) async {
      final currentRows = await txn.query(
        ChallengeTable.tableName,
        columns: [ChallengeTable.colStatus, ChallengeTable.colUpdatedAt],
        where: '${ChallengeTable.colId} = ?',
        whereArgs: [id],
      );
      if (currentRows.isEmpty) {
        throw const ChallengeException('Challenge introuvable');
      }
      if (currentRows.first[ChallengeTable.colStatus] ==
          ChallengeStatus.cancelled.value) {
        throw const ChallengeException(
          'Un challenge annulé ne peut pas être modifié',
        );
      }
      if (currentRows.first[ChallengeTable.colStatus] !=
              existing.status.value ||
          currentRows.first[ChallengeTable.colUpdatedAt] !=
              existing.updatedAt.toIso8601String()) {
        throw const ChallengeException(
          'Ce challenge a changé. Rechargez-le avant de le modifier.',
        );
      }
      final currentUser = SessionManager.instance.currentUser;
      if (currentUser == null ||
          !Permissions.canModifyChallenge(currentUser, existing.createdBy) ||
          currentUser.id != user?.id) {
        throw const ChallengeException('La session a changé, reconnectez-vous');
      }
      if (coachEditLocked(currentUser, existing, _now())) {
        throw const ChallengeException(
          'Un coach ne peut plus modifier un challenge dès sa date de début',
        );
      }

      final participantRows = await txn.rawQuery(
        'SELECT COUNT(*) AS count FROM ${ChallengeParticipantTable.tableName} '
        'WHERE ${ChallengeParticipantTable.colChallengeId} = ?',
        [id],
      );
      final hasParticipants = (Sqflite.firstIntValue(participantRows) ?? 0) > 0;
      if (hasParticipants &&
          (tasksChanged ||
              startDateChanged ||
              challenge.difficulty != existing.difficulty ||
              challenge.xpReward != existing.xpReward ||
              challenge.endDate.isBefore(existing.endDate))) {
        throw const ChallengeException(
          'Le challenge a maintenant des participants. Ses tâches, sa '
          'difficulté, ses XP et sa date de début sont verrouillés ; '
          'la date de fin peut seulement être prolongée.',
        );
      }

      await txn.update(
        ChallengeTable.tableName,
        map,
        where: '${ChallengeTable.colId} = ?',
        whereArgs: [id],
      );

      // Keep task IDs/progress intact whenever participants exist.
      if (!hasParticipants) {
        await txn.delete(
          ChallengeTaskTable.tableName,
          where: '${ChallengeTaskTable.colChallengeId} = ?',
          whereArgs: [id],
        );
        for (var i = 0; i < tasks.length; i++) {
          final taskMap =
              tasks[i]
                  .copyWith(
                    challengeId: id,
                    title: tasks[i].title.trim(),
                    orderIndex: i,
                  )
                  .toMap()
                ..remove(ChallengeTaskTable.colId);
          await txn.insert(ChallengeTaskTable.tableName, taskMap);
        }
      }
      if (user != null &&
          user.id != null &&
          existing.status == ChallengeStatus.rejected &&
          needsResubmission(user, existing.status)) {
        await _notifyAdmins(txn, user, challenge, id, now);
      }
    });

    final updated = await getChallengeById(id);
    if (updated == null) {
      throw const ChallengeException('Le challenge n\'a pas pu être rechargé');
    }
    return updated;
  }

  bool _sameTasks(List<ChallengeTask> a, List<ChallengeTask> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final left = a[i];
      final right = b[i];
      final leftDates =
          left.scheduledDates.map(ChallengeTaskLog.dateKey).toList()..sort();
      final rightDates =
          right.scheduledDates.map(ChallengeTaskLog.dateKey).toList()..sort();
      if (left.title.trim() != right.title.trim() ||
          _cleanDescription(left.description) !=
              _cleanDescription(right.description) ||
          left.type != right.type ||
          left.unit != right.unit ||
          left.targetValue != right.targetValue ||
          left.xpReward != right.xpReward ||
          !listEquals(leftDates, rightDates)) {
        return false;
      }
    }
    return true;
  }

  String? _cleanDescription(String? description) {
    final value = description?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// Annule un challenge sans supprimer ses inscriptions ni sa progression.
  Future<void> cancelChallenge(int id) async {
    final existing = await getChallengeById(id);
    if (existing == null) {
      throw const ChallengeException('Challenge introuvable');
    }
    if (!Permissions.currentCanModifyChallenge(existing.createdBy)) {
      throw const ChallengeException(
        'Vous n\'avez pas le droit d\'annuler ce challenge',
      );
    }
    if (existing.status == ChallengeStatus.cancelled) return;

    final db = await _db;
    await db.update(
      ChallengeTable.tableName,
      {
        ChallengeTable.colStatus: ChallengeStatus.cancelled.value,
        ChallengeTable.colUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${ChallengeTable.colId} = ?',
      whereArgs: [id],
    );
  }

  /// Supprime un challenge uniquement s'il n'a jamais eu de participant.
  Future<void> deleteChallenge(int id) async {
    final existing = await getChallengeById(id);
    if (existing == null) {
      throw const ChallengeException('Challenge introuvable');
    }
    if (!Permissions.currentCanModifyChallenge(existing.createdBy)) {
      throw const ChallengeException(
        'Vous n\'avez pas le droit de supprimer ce challenge',
      );
    }
    final db = await _db;
    await db.transaction((txn) async {
      final participantRows = await txn.rawQuery(
        'SELECT COUNT(*) AS count FROM ${ChallengeParticipantTable.tableName} '
        'WHERE ${ChallengeParticipantTable.colChallengeId} = ?',
        [id],
      );
      if ((Sqflite.firstIntValue(participantRows) ?? 0) > 0) {
        throw const ChallengeException(
          'Ce challenge a déjà des participants. Annulez-le plutôt que de le supprimer.',
        );
      }
      await txn.delete(
        ChallengeTable.tableName,
        where: '${ChallengeTable.colId} = ?',
        whereArgs: [id],
      );
    });
    unawaited(
      _notifications.refreshUnreadCount().catchError(
        (Object e, StackTrace s) =>
            debugPrint('ERREUR COMPTE NOTIFICATIONS : $e\n$s'),
      ),
    );
    try {
      await deleteCover(existing.imagePath);
    } on FileSystemException {
      // The database deletion succeeded; a stale cover file must not block it.
    }
  }

  Future<int> countParticipants(int challengeId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM ${ChallengeParticipantTable.tableName} '
      'WHERE ${ChallengeParticipantTable.colChallengeId} = ?',
      [challengeId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  User _viewer() {
    final user = SessionManager.instance.currentUser;
    if (user == null || !Permissions.can(user, Permission.viewChallenges)) {
      throw const ChallengeException('Vous n\'avez pas accès aux challenges');
    }
    return user;
  }

  User _reviewer() {
    final user = SessionManager.instance.currentUser;
    if (user == null || !Permissions.can(user, Permission.reviewChallenges)) {
      throw const ChallengeException(
        'Vous n\'avez pas le droit de valider les challenges',
      );
    }
    if (user.id == null) {
      throw const ChallengeException('Session invalide, reconnectez-vous');
    }
    return user;
  }

  Future<void> approveChallenge(int id) => _reviewChallenge(id);

  Future<void> rejectChallenge(int id, String reason) =>
      _reviewChallenge(id, reason: reason);

  Future<void> _reviewChallenge(int id, {String? reason}) async {
    final reviewer = _reviewer();
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        ChallengeTable.tableName,
        where: '${ChallengeTable.colId} = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) throw const ChallengeException('Challenge introuvable');
      final existing = Challenge.fromMap(rows.first);
      final now = DateTime.now();
      validateReview(existing, reason: reason, now: now);
      await txn.update(
        ChallengeTable.tableName,
        {
          ChallengeTable.colStatus:
              (reason == null
                      ? ChallengeStatus.active
                      : ChallengeStatus.rejected)
                  .value,
          ChallengeTable.colRejectionReason: reason?.trim(),
          ChallengeTable.colReviewedBy: reviewer.id,
          ChallengeTable.colReviewedAt: now.toIso8601String(),
          ChallengeTable.colUpdatedAt: now.toIso8601String(),
        },
        where: '${ChallengeTable.colId} = ?',
        whereArgs: [id],
      );
      if (reason == null) {
        await _notifyMembers(txn, reviewer.id!, existing, id, now);
      }
      await _notifications.insertBatch(
        txn,
        recipients: [existing.createdBy],
        actorId: reviewer.id!,
        type: reason == null
            ? NotificationType.challengeApproved
            : NotificationType.challengeRejected,
        title: reason == null ? 'Challenge approuvé' : 'Challenge rejeté',
        body: reason == null
            ? 'Votre challenge « ${existing.title} » a été approuvé.'
            : 'Votre challenge « ${existing.title} » a été rejeté : ${reason.trim()}',
        challengeId: id,
        createdAt: now,
      );
    });
  }

  Future<void> _notifyMembers(
    DatabaseExecutor txn,
    int actorId,
    Challenge challenge,
    int id,
    DateTime now,
  ) => _notifications.insertForRole(
    txn,
    role: UserRole.member,
    actorId: actorId,
    type: NotificationType.challengePosted,
    title: 'Nouveau challenge',
    body:
        '« ${challenge.title} » · ${challenge.difficulty.label} · Fin le ${formatChallengeDate(challenge.endDate)}',
    challengeId: id,
    createdAt: now,
  );

  Future<void> _notifyAdmins(
    DatabaseExecutor txn,
    User coach,
    Challenge challenge,
    int id,
    DateTime now,
  ) => _notifications.insertForRole(
    txn,
    role: UserRole.admin,
    actorId: coach.id!,
    type: NotificationType.challengePendingReview,
    title: 'Nouveau challenge à valider',
    body: '${coach.fullName} a soumis « ${challenge.title.trim()} ».',
    challengeId: id,
    createdAt: now,
  );

  Future<Map<ChallengeStatus, int>> getChallengeCountsByStatus() async {
    _reviewer();
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT ${ChallengeTable.colStatus}, COUNT(*) AS count '
      'FROM ${ChallengeTable.tableName} GROUP BY ${ChallengeTable.colStatus}',
    );
    return {
      for (final status in ChallengeStatus.values)
        status: rows
            .where((r) => r[ChallengeTable.colStatus] == status.value)
            .fold(0, (sum, r) => sum + (r['count'] as int)),
    };
  }

  Future<int> getPendingCount() async =>
      (await getChallengeCountsByStatus())[ChallengeStatus.pending]!;

  static const String _selectWithCreator =
      '''
    SELECT c.*,
      (u.${UserTable.colFirstName} || ' ' || u.${UserTable.colLastName})
        AS ${ChallengeTable.colCreatorName},
      (reviewer.${UserTable.colFirstName} || ' ' || reviewer.${UserTable.colLastName})
        AS ${ChallengeTable.colReviewerName},
      (SELECT COUNT(*) FROM ${ChallengeTaskTable.tableName} t
        WHERE t.${ChallengeTaskTable.colChallengeId} = c.${ChallengeTable.colId})
        AS task_count
    FROM ${ChallengeTable.tableName} c
    LEFT JOIN ${UserTable.tableName} u
      ON u.${UserTable.colId} = c.${ChallengeTable.colCreatedBy}
    LEFT JOIN ${UserTable.tableName} reviewer
      ON reviewer.${UserTable.colId} = c.${ChallengeTable.colReviewedBy}
  ''';

  /// Liste des challenges (sans leurs tâches, mais avec leur nombre),
  /// du plus récent au plus ancien.
  Future<List<Challenge>> getChallenges({
    ChallengeStatus? status,
    int? createdBy,
  }) async {
    final user = _viewer();
    final where = <String>[];
    final args = <Object?>[];
    if (user.role == UserRole.coach) {
      where.add(
        '(c.${ChallengeTable.colStatus} = ? OR c.${ChallengeTable.colCreatedBy} = ?)',
      );
      args.addAll([ChallengeStatus.active.value, user.id]);
    } else if (user.role != UserRole.admin) {
      where.add('c.${ChallengeTable.colStatus} = ?');
      args.add(ChallengeStatus.active.value);
    }
    if (status != null) {
      where.add('c.${ChallengeTable.colStatus} = ?');
      args.add(status.value);
    }
    if (createdBy != null) {
      where.add('c.${ChallengeTable.colCreatedBy} = ?');
      args.add(createdBy);
    }

    final db = await _db;
    final rows = await db.rawQuery(
      '$_selectWithCreator '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY c.${ChallengeTable.colStartDate} DESC, '
      'c.${ChallengeTable.colId} DESC',
      args,
    );
    return rows.map((row) => Challenge.fromMap(row)).toList();
  }

  /// Un challenge avec ses tâches triées par orderIndex (null s'il n'existe pas).
  Future<Challenge?> getChallengeById(int id) async {
    final user = _viewer();
    final db = await _db;
    final rows = await db.rawQuery(
      '$_selectWithCreator WHERE c.${ChallengeTable.colId} = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    final challenge = Challenge.fromMap(rows.first);
    if (!canViewChallenge(user, challenge)) {
      throw const ChallengeException('Vous n\'avez pas accès à ce challenge');
    }

    final taskRows = await db.query(
      ChallengeTaskTable.tableName,
      where: '${ChallengeTaskTable.colChallengeId} = ?',
      whereArgs: [id],
      orderBy: '${ChallengeTaskTable.colOrderIndex} ASC',
    );
    return Challenge.fromMap(
      rows.first,
      tasks: taskRows.map(ChallengeTask.fromMap).toList(),
    );
  }

  // ---------- Image de couverture ----------

  /// Ouvre la caméra ou la galerie et copie l'image dans le dossier privé
  /// de l'application. Renvoie son chemin (null si annulé).
  Future<String?> pickCover(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return null;

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'challenges'));
    if (!await dir.exists()) await dir.create(recursive: true);

    final ext = p.extension(file.path).isEmpty
        ? '.jpg'
        : p.extension(file.path);
    final dest = p.join(
      dir.path,
      'cover_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(file.path).copy(dest);
    return dest;
  }

  Future<void> deleteCover(String? path) async {
    if (path == null) return;
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
