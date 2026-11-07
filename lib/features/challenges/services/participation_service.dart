import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/session/permissions.dart';
import '../../../core/session/session_manager.dart';
import '../../users/models/user_table.dart';
import '../../users/services/xp_service.dart';
import '../models/challenge.dart';
import '../models/challenge_participant.dart';
import '../models/challenge_status.dart';
import '../models/challenge_table.dart';
import '../models/challenge_task.dart';
import '../models/challenge_task_progress.dart';
import '../models/challenge_task_log.dart';
import '../models/day_plan.dart';
import '../models/participant_status.dart';
import 'challenge_service.dart';

class MyChallenge {
  const MyChallenge(this.challenge, this.participation);
  final Challenge challenge;
  final ChallengeParticipant participation;
}

class CalendarDayDetail {
  const CalendarDayDetail(this.entry, this.day);
  final MyChallenge entry;
  final DayPlan day;
}

class ParticipationService {
  ParticipationService._()
    : _database = (() => DatabaseHelper.instance.database),
      _now = DateTime.now;

  @visibleForTesting
  ParticipationService.forDatabase(
    Future<Database> Function() database, {
    DateTime Function()? now,
  }) : _database = database,
       _now = now ?? DateTime.now;

  static final instance = ParticipationService._();
  final Future<Database> Function() _database;
  final DateTime Function() _now;

  int _memberId() {
    final user = SessionManager.instance.currentUser;
    if (user == null ||
        user.id == null ||
        !Permissions.can(user, Permission.joinChallenge)) {
      throw const ChallengeException('Réservé aux membres actifs');
    }
    return user.id!;
  }

  void _checkSession(int id) {
    if (_memberId() != id) {
      throw const ChallengeException('La session a changé, reconnectez-vous');
    }
  }

  void _checkAvailable(Challenge challenge, DateTime now) {
    if (challenge.status != ChallengeStatus.active) {
      throw const ChallengeException('Ce challenge n’est pas disponible');
    }
    if (challenge.timeStateAt(now) == ChallengeTimeState.ended) {
      throw const ChallengeException('Ce challenge est terminé');
    }
  }

  Future<void> joinChallenge(int challengeId) async {
    final userId = _memberId();
    final db = await _database();
    await db.transaction((txn) async {
      _checkSession(userId);
      final challenges = await txn.query(
        ChallengeTable.tableName,
        where: '${ChallengeTable.colId} = ?',
        whereArgs: [challengeId],
      );
      if (challenges.isEmpty) {
        throw const ChallengeException('Challenge introuvable');
      }
      _checkAvailable(Challenge.fromMap(challenges.first), _now());
      final rows = await txn.query(
        ChallengeParticipantTable.tableName,
        where:
            '${ChallengeParticipantTable.colChallengeId} = ? AND ${ChallengeParticipantTable.colUserId} = ?',
        whereArgs: [challengeId, userId],
      );
      if (rows.isNotEmpty) {
        final participant = ChallengeParticipant.fromMap(rows.first);
        if (participant.status != ParticipantStatus.abandoned) {
          throw const ChallengeException('Vous participez déjà à ce challenge');
        }
        await txn.update(
          ChallengeParticipantTable.tableName,
          {ChallengeParticipantTable.colStatus: ParticipantStatus.joined.value},
          where: '${ChallengeParticipantTable.colId} = ?',
          whereArgs: [participant.id],
        );
      } else {
        final tasks = await txn.query(
          ChallengeTaskTable.tableName,
          columns: [ChallengeTaskTable.colId],
          where: '${ChallengeTaskTable.colChallengeId} = ?',
          whereArgs: [challengeId],
        );
        if (tasks.isEmpty) {
          throw const ChallengeException(
            'Ce challenge ne contient aucune tâche',
          );
        }
        final id = await txn.insert(
          ChallengeParticipantTable.tableName,
          ChallengeParticipant(
            challengeId: challengeId,
            userId: userId,
            status: ParticipantStatus.joined,
            joinedAt: _now(),
          ).toMap(),
        );
        final batch = txn.batch();
        for (final task in tasks) {
          batch.insert(
            ChallengeTaskProgressTable.tableName,
            ChallengeTaskProgress(
              participantId: id,
              taskId: task[ChallengeTaskTable.colId] as int,
            ).toMap(),
          );
        }
        await batch.commit(noResult: true);
      }
      _checkSession(userId);
    });
  }

  Future<void> leaveChallenge(int challengeId) async {
    final userId = _memberId();
    final db = await _database();
    await db.transaction((txn) async {
      _checkSession(userId);
      final changed = await txn.update(
        ChallengeParticipantTable.tableName,
        {
          ChallengeParticipantTable.colStatus:
              ParticipantStatus.abandoned.value,
        },
        where:
            '${ChallengeParticipantTable.colChallengeId} = ? AND ${ChallengeParticipantTable.colUserId} = ? AND ${ChallengeParticipantTable.colStatus} = ?',
        whereArgs: [challengeId, userId, ParticipantStatus.joined.value],
      );
      if (changed != 1) {
        throw const ChallengeException('Vous ne participez pas à ce challenge');
      }
      _checkSession(userId);
    });
  }

  Future<bool> logProgress(int taskId, DateTime day, double amount) async {
    final userId = _memberId();
    if (!amount.isFinite || amount <= 0) {
      throw const ChallengeException('L’avancement doit être supérieur à 0');
    }
    final db = await _database();
    final updatedXp = await db.transaction<int?>((txn) async {
      _checkSession(userId);
      final rows = await txn.rawQuery(
        '''
        SELECT p.id AS participant_id, p.status AS participant_status,
          t.target_value, t.scheduled_dates, g.id AS progress_id, g.progress, g.completed,
          c.*
        FROM challenge_tasks t
        JOIN challenge_participants p ON p.challenge_id = t.challenge_id AND p.user_id = ?
        JOIN challenge_task_progress g ON g.participant_id = p.id AND g.task_id = t.id
        JOIN challenges c ON c.id = t.challenge_id
        WHERE t.id = ?
      ''',
        [userId, taskId],
      );
      if (rows.isEmpty ||
          rows.first['participant_status'] != ParticipantStatus.joined.value) {
        throw const ChallengeException('Vous ne participez pas à ce challenge');
      }
      final row = rows.first;
      final challenge = Challenge.fromMap(row);
      final now = _now();
      if (challenge.status != ChallengeStatus.active) {
        throw const ChallengeException('Ce challenge n’est pas disponible');
      }
      if (challenge.timeStateAt(now) == ChallengeTimeState.ended) {
        throw const ChallengeException(
          'Ce challenge est terminé : la progression est verrouillée',
        );
      }
      final key = ChallengeTaskLog.dateKey(day);
      if (key.compareTo(ChallengeTaskLog.dateKey(challenge.startDate)) < 0 ||
          key.compareTo(ChallengeTaskLog.dateKey(challenge.endDate)) > 0 ||
          key.compareTo(ChallengeTaskLog.dateKey(now)) > 0) {
        throw const ChallengeException('La date choisie n’est pas disponible');
      }
      final scheduledDates = ChallengeTask.decodeScheduledDates(
        row['scheduled_dates'],
      );
      if (scheduledDates.isNotEmpty &&
          !scheduledDates.any(
            (date) => ChallengeTaskLog.dateKey(date) == key,
          )) {
        throw const ChallengeException(
          'Cette tâche n’est pas prévue à cette date',
        );
      }
      if (row['completed'] == 1) {
        throw const ChallengeException('Cette tâche est déjà terminée');
      }
      final target = (row['target_value'] as num).toDouble();
      final current = (row['progress'] as num).toDouble();
      final remaining = target - current;
      final tolerance = target.abs() * 1e-12;
      if (amount > remaining + tolerance) {
        throw ChallengeException('Objectif restant : $remaining');
      }
      final progress = (current + amount >= target - tolerance)
          ? target
          : current + amount;
      final done = progress == target;
      final logs = await txn.query(
        ChallengeTaskLogTable.tableName,
        where: 'participant_id = ? AND task_id = ? AND log_date = ?',
        whereArgs: [row['participant_id'], taskId, key],
      );
      if (logs.isEmpty) {
        await txn.insert(
          ChallengeTaskLogTable.tableName,
          ChallengeTaskLog(
            participantId: row['participant_id'] as int,
            taskId: taskId,
            logDate: day,
            amount: progress - current,
            createdAt: now,
          ).toMap(),
        );
      } else {
        await txn.update(
          ChallengeTaskLogTable.tableName,
          {
            'amount':
                (logs.first['amount'] as num).toDouble() + progress - current,
          },
          where: 'id = ?',
          whereArgs: [logs.first['id']],
        );
      }
      await txn.update(
        ChallengeTaskProgressTable.tableName,
        {
          ChallengeTaskProgressTable.colProgress: progress,
          ChallengeTaskProgressTable.colCompleted: done ? 1 : 0,
          ChallengeTaskProgressTable.colCompletedAt: done
              ? now.toIso8601String()
              : null,
        },
        where: '${ChallengeTaskProgressTable.colId} = ?',
        whereArgs: [row['progress_id']],
      );
      final outstanding = await txn.rawQuery(
        'SELECT COUNT(*) FROM challenge_task_progress WHERE participant_id = ? AND completed = 0',
        [row['participant_id']],
      );
      final allDone = Sqflite.firstIntValue(outstanding) == 0;
      if (allDone) {
        final changed = await txn.update(
          ChallengeParticipantTable.tableName,
          {
            ChallengeParticipantTable.colStatus:
                ParticipantStatus.completed.value,
            ChallengeParticipantTable.colCompletedAt: now.toIso8601String(),
          },
          where:
              '${ChallengeParticipantTable.colId} = ? AND ${ChallengeParticipantTable.colStatus} = ?',
          whereArgs: [row['participant_id'], ParticipantStatus.joined.value],
        );
        if (changed != 1) {
          throw const ChallengeException('La participation a changé');
        }
        await XpService.instance.addXpInTransaction(
          txn,
          userId: userId,
          amount: challenge.xpReward,
          type: 'challenge_completion',
          description: 'Challenge terminé : ${challenge.title}',
        );
        final users = await txn.query(
          UserTable.tableName,
          columns: [UserTable.colXp],
          where: '${UserTable.colId} = ?',
          whereArgs: [userId],
        );
        if (users.isEmpty) {
          throw const ChallengeException('Utilisateur introuvable');
        }
        _checkSession(userId);
        return users.first[UserTable.colXp] as int;
      }
      _checkSession(userId);
      return null;
    });
    final user = SessionManager.instance.currentUser;
    if (updatedXp != null && user?.id == userId) {
      SessionManager.instance.currentUser = user!.copyWith(xp: updatedXp);
    }
    return updatedXp != null;
  }

  Future<ChallengeParticipant?> _participation(
    DatabaseExecutor db,
    int challengeId,
    int userId,
  ) async {
    final rows = await db.query(
      ChallengeParticipantTable.tableName,
      where:
          '${ChallengeParticipantTable.colChallengeId} = ? AND ${ChallengeParticipantTable.colUserId} = ?',
      whereArgs: [challengeId, userId],
    );
    if (rows.isEmpty) return null;
    final tasks = await db.rawQuery(
      'SELECT g.*, t.target_value FROM challenge_task_progress g '
      'JOIN challenge_tasks t ON t.id = g.task_id WHERE g.participant_id = ?',
      [rows.first['id']],
    );
    return ChallengeParticipant.fromMap(
      rows.first,
      tasks: tasks.map(ChallengeTaskProgress.fromMap).toList(),
    );
  }

  Future<ChallengeParticipant?> getMyParticipation(int challengeId) async {
    final id = _memberId();
    final db = await _database();
    final result = await _participation(db, challengeId, id);
    _checkSession(id);
    return result;
  }

  Future<List<MyChallenge>> getMyChallenges() async {
    final userId = _memberId();
    final db = await _database();
    final rows = await db.rawQuery(
      '''
      SELECT c.*, (u.first_name || ' ' || u.last_name) AS creator_name
      FROM challenges c JOIN challenge_participants p ON p.challenge_id = c.id
      LEFT JOIN users u ON u.id = c.created_by
      WHERE p.user_id = ? ORDER BY p.joined_at DESC, p.id DESC
    ''',
      [userId],
    );
    final result = <MyChallenge>[];
    for (final row in rows) {
      final id = row['id'] as int;
      final participation = await _participation(db, id, userId);
      final tasks = await db.query(
        ChallengeTaskTable.tableName,
        where: '${ChallengeTaskTable.colChallengeId} = ?',
        whereArgs: [id],
        orderBy: '${ChallengeTaskTable.colOrderIndex} ASC',
      );
      if (participation != null) {
        result.add(
          MyChallenge(
            Challenge.fromMap(
              row,
              tasks: tasks.map(ChallengeTask.fromMap).toList(),
            ),
            participation,
          ),
        );
      }
    }
    _checkSession(userId);
    return result;
  }

  int _calendarMemberId() {
    final user = SessionManager.instance.currentUser;
    if (user == null ||
        user.id == null ||
        !Permissions.can(user, Permission.joinChallenge)) {
      throw const ChallengeException('Réservé aux membres');
    }
    return user.id!;
  }

  Future<List<MyChallenge>> getCalendarEntries() async {
    final userId = _calendarMemberId();
    final entries = await getMyChallenges();
    if (_calendarMemberId() != userId) {
      throw const ChallengeException('La session a changé, reconnectez-vous');
    }
    return entries;
  }

  Future<Map<String, int>> getLoggedDays(DateTime from, DateTime to) async {
    final userId = _calendarMemberId();
    final start = ChallengeTaskLog.dateKey(from);
    final end = ChallengeTaskLog.dateKey(to);
    if (start.compareTo(end) > 0) {
      throw const ChallengeException('La période du calendrier est invalide');
    }
    final db = await _database();
    final rows = await db.rawQuery(
      '''
      SELECT l.log_date, COUNT(*) AS task_count
      FROM challenge_task_logs l
      JOIN challenge_participants p ON p.id = l.participant_id
      WHERE p.user_id = ? AND l.log_date >= ? AND l.log_date <= ?
      GROUP BY l.log_date
    ''',
      [userId, start, end],
    );
    if (_calendarMemberId() != userId) {
      throw const ChallengeException('La session a changé, reconnectez-vous');
    }
    return {
      for (final row in rows)
        row['log_date'] as String: row['task_count'] as int,
    };
  }

  Future<List<CalendarDayDetail>> getDayDetail(DateTime day) async {
    final userId = _calendarMemberId();
    final entries = await getCalendarEntries();
    final key = ChallengeTaskLog.dateKey(day);
    final result = <CalendarDayDetail>[];
    for (final entry in entries) {
      final challenge = entry.challenge;
      if (key.compareTo(ChallengeTaskLog.dateKey(challenge.startDate)) < 0 ||
          key.compareTo(ChallengeTaskLog.dateKey(challenge.endDate)) > 0) {
        continue;
      }
      final plans = await getDayPlan(challenge.id!);
      final plan = plans.firstWhere(
        (plan) => ChallengeTaskLog.dateKey(plan.date) == key,
      );
      result.add(CalendarDayDetail(entry, plan));
    }
    if (_calendarMemberId() != userId) {
      throw const ChallengeException('La session a changé, reconnectez-vous');
    }
    return result;
  }

  Future<Challenge?> getMyChallenge(int challengeId) async {
    final challenges = await getMyChallenges();
    for (final entry in challenges) {
      if (entry.challenge.id == challengeId) return entry.challenge;
    }
    return null;
  }

  Future<List<DayPlan>> getDayPlan(int challengeId) async {
    final userId = _memberId();
    final db = await _database();
    final participant = await _participation(db, challengeId, userId);
    if (participant == null) {
      throw const ChallengeException('Vous ne participez pas à ce challenge');
    }
    final rows = await db.query(
      ChallengeTable.tableName,
      where: '${ChallengeTable.colId} = ?',
      whereArgs: [challengeId],
    );
    if (rows.isEmpty) throw const ChallengeException('Challenge introuvable');
    final tasks = await db.query(
      ChallengeTaskTable.tableName,
      where: '${ChallengeTaskTable.colChallengeId} = ?',
      whereArgs: [challengeId],
      orderBy: '${ChallengeTaskTable.colOrderIndex} ASC',
    );
    final logs = await db.query(
      ChallengeTaskLogTable.tableName,
      where: '${ChallengeTaskLogTable.colParticipantId} = ?',
      whereArgs: [participant.id],
    );
    _checkSession(userId);
    return buildDayPlans(
      Challenge.fromMap(
        rows.first,
        tasks: tasks.map(ChallengeTask.fromMap).toList(),
      ),
      participant.tasks,
      logs.map(ChallengeTaskLog.fromMap).toList(),
      _now(),
    );
  }
}
