import 'package:flutter_test/flutter_test.dart';
import 'package:mygym/core/session/permissions.dart';
import 'package:mygym/core/session/session_manager.dart';
import 'package:mygym/features/challenges/models/challenge.dart';
import 'package:mygym/features/challenges/models/challenge_difficulty.dart';
import 'package:mygym/features/challenges/models/challenge_status.dart';
import 'package:mygym/features/challenges/models/challenge_task.dart';
import 'package:mygym/features/challenges/models/challenge_type.dart';
import 'package:mygym/features/challenges/models/challenge_unit.dart';
import 'package:mygym/features/challenges/services/challenge_service.dart';
import 'package:mygym/features/users/models/user.dart';
import 'package:mygym/features/users/models/user_role.dart';
import 'package:mygym/features/users/models/user_status.dart';

void main() {
  final now = DateTime(2026, 6, 10, 9);
  final start = DateTime(2026, 6, 11);
  final end = DateTime(2026, 6, 20, 23, 59, 59);

  Challenge challenge({
    String title = 'Défi été',
    int xp = 100,
    DateTime? startDate,
    DateTime? endDate,
  }) => Challenge(
    title: title,
    xpReward: xp,
    startDate: startDate ?? start,
    endDate: endDate ?? end,
    createdBy: 1,
    createdAt: now,
    updatedAt: now,
  );

  const task = ChallengeTask(title: 'Pompes', targetValue: 20);

  User user({
    int id = 1,
    UserRole role = UserRole.coach,
    UserStatus status = UserStatus.active,
  }) => User(
    id: id,
    firstName: 'Test',
    lastName: 'User',
    email: 'test@example.com',
    passwordHash: 'hash',
    phone: '12345678',
    role: role,
    status: status,
    createdAt: now,
  );

  void expectInvalid(Challenge c, List<ChallengeTask> tasks) {
    expect(
      () => ChallengeService.validate(c, tasks, now: now),
      throwsA(isA<ChallengeException>()),
    );
  }

  group('toMap / fromMap', () {
    test('ChallengeTask round trip', () {
      const t = ChallengeTask(
        id: 3,
        challengeId: 7,
        title: 'Courir',
        description: 'Dehors',
        type: ChallengeType.running,
        unit: ChallengeUnit.km,
        targetValue: 5.5,
        xpReward: 20,
        orderIndex: 2,
      );
      final back = ChallengeTask.fromMap(t.toMap());
      expect(back.toMap(), t.toMap());
      expect(back.type, ChallengeType.running);
      expect(back.targetValue, 5.5);
    });

    test('scheduled dates round-trip and empty schedules stay automatic', () {
      final dated = task.copyWith(
        scheduledDates: [DateTime(2026, 6, 11), DateTime(2026, 6, 15)],
      );
      final restored = ChallengeTask.fromMap(dated.toMap());
      expect(restored.scheduledDates, [
        DateTime(2026, 6, 11),
        DateTime(2026, 6, 15),
      ]);
      expect(restored.isScheduledOn(DateTime(2026, 6, 15, 20)), isTrue);
      expect(restored.isScheduledOn(DateTime(2026, 6, 14)), isFalse);
      expect(
        ChallengeTask.fromMap(task.toMap()).isScheduledOn(DateTime(2030)),
        isTrue,
      );
    });

    test('Challenge round trip', () {
      final c = Challenge(
        id: 4,
        title: 'Défi',
        description: 'desc',
        difficulty: ChallengeDifficulty.hard,
        xpReward: 200,
        startDate: start,
        endDate: end,
        status: ChallengeStatus.active,
        imagePath: '/x.jpg',
        createdBy: 2,
        createdAt: now,
        updatedAt: now,
      );
      final back = Challenge.fromMap(c.toMap());
      expect(back.toMap(), c.toMap());
      expect(back.startDate, start);
      expect(back.difficulty, ChallengeDifficulty.hard);
    });

    test('time state is derived from the dates', () {
      final c = challenge();
      expect(c.timeStateAt(DateTime(2026, 6, 1)), ChallengeTimeState.upcoming);
      expect(c.timeStateAt(DateTime(2026, 6, 15)), ChallengeTimeState.ongoing);
      expect(c.timeStateAt(DateTime(2026, 7, 1)), ChallengeTimeState.ended);
    });

    test('start and end dates are inclusive calendar days', () {
      final c = challenge(
        startDate: DateTime(2026, 6, 11, 18),
        endDate: DateTime(2026, 6, 20, 8),
      );
      expect(
        c.timeStateAt(DateTime(2026, 6, 10, 23, 59)),
        ChallengeTimeState.upcoming,
      );
      expect(c.timeStateAt(DateTime(2026, 6, 11)), ChallengeTimeState.ongoing);
      expect(
        c.timeStateAt(DateTime(2026, 6, 20, 23, 59, 59)),
        ChallengeTimeState.ongoing,
      );
      expect(c.timeStateAt(DateTime(2026, 6, 21)), ChallengeTimeState.ended);
    });
  });

  group('validation', () {
    test('task dates must be unique and within the challenge', () {
      for (final dates in [
        [DateTime(2026, 6, 10)],
        [DateTime(2026, 6, 21)],
        [DateTime(2026, 6, 11), DateTime(2026, 6, 11, 12)],
      ]) {
        expectInvalid(challenge(), [task.copyWith(scheduledDates: dates)]);
      }
      ChallengeService.validate(challenge(), [
        task.copyWith(scheduledDates: [start, end]),
      ], now: now);
    });
    test('valid challenge passes', () {
      ChallengeService.validate(challenge(), [task], now: now);
    });

    test(
      'rejects short title',
      () => expectInvalid(challenge(title: 'ab'), [task]),
    );
    test('rejects no tasks', () => expectInvalid(challenge(), []));
    test(
      'rejects more than 20 tasks',
      () => expectInvalid(challenge(), List.filled(21, task)),
    );
    test('accepts exactly 20 tasks', () {
      ChallengeService.validate(challenge(), List.filled(20, task), now: now);
    });
    test(
      'rejects end before start',
      () => expectInvalid(challenge(endDate: DateTime(2026, 6, 5)), [task]),
    );
    test(
      'rejects start in the past',
      () => expectInvalid(challenge(startDate: DateTime(2026, 6, 9)), [task]),
    );
    test('accepts start today', () {
      ChallengeService.validate(challenge(startDate: DateTime(2026, 6, 10)), [
        task,
      ], now: now);
    });
    test(
      'an unchanged past start date is allowed during update validation',
      () {
        ChallengeService.validate(
          challenge(startDate: DateTime(2026, 6, 9)),
          [task],
          now: now,
          validateStartDate: false,
        );
      },
    );
    test(
      'rejects blank task title',
      () => expectInvalid(challenge(), [
        const ChallengeTask(title: ' ', targetValue: 1),
      ]),
    );
    test(
      'rejects target <= 0',
      () => expectInvalid(challenge(), [
        const ChallengeTask(title: 'a', targetValue: 0),
      ]),
    );
    test(
      'rejects challenge XP above cap',
      () => expectInvalid(challenge(xp: 501), [task]),
    );
    test(
      'rejects task XP above cap',
      () => expectInvalid(challenge(), [
        const ChallengeTask(title: 'a', targetValue: 1, xpReward: 101),
      ]),
    );
  });

  group('challenge modification permissions', () {
    test('coach cannot modify another coach’s challenge', () {
      expect(Permissions.canModifyChallenge(user(id: 1), 2), isFalse);
    });

    test('coach can modify their own challenge', () {
      expect(Permissions.canModifyChallenge(user(id: 1), 1), isTrue);
    });

    test('admin cannot manage or modify challenges', () {
      expect(
        Permissions.can(user(role: UserRole.admin), Permission.manageChallenges),
        isFalse,
      );
      expect(
        Permissions.canModifyChallenge(user(role: UserRole.admin), 99),
        isFalse,
      );
    });

    test('admin cannot create a challenge through the service', () async {
      SessionManager.instance.currentUser = user(role: UserRole.admin);
      addTearDown(SessionManager.instance.logout);
      await expectLater(
        ChallengeService.instance.createChallenge(challenge(), [task]),
        throwsA(isA<ChallengeException>()),
      );
    });

    test('inactive coach cannot modify a challenge', () {
      expect(
        Permissions.canModifyChallenge(user(status: UserStatus.disabled), 1),
        isFalse,
      );
    });
  });

  group('approval policy', () {
    tearDown(() => SessionManager.instance.logout());

    test(
      'new coach challenges are pending and admin challenges are active',
      () {
        expect(ChallengeService.initialStatus(user()), ChallengeStatus.pending);
        expect(
          ChallengeService.initialStatus(user(role: UserRole.admin)),
          ChallengeStatus.active,
        );
      },
    );

    test('coach and member cannot approve or reject', () async {
      for (final role in [UserRole.coach, UserRole.member]) {
        SessionManager.instance.currentUser = user(role: role);
        await expectLater(
          ChallengeService.instance.approveChallenge(1),
          throwsA(isA<ChallengeException>()),
        );
        await expectLater(
          ChallengeService.instance.rejectChallenge(1, 'Motif suffisant'),
          throwsA(isA<ChallengeException>()),
        );
      }
      expect(
        Permissions.can(
          user(role: UserRole.admin),
          Permission.reviewChallenges,
        ),
        isTrue,
      );
      expect(
        Permissions.can(
          user(role: UserRole.admin, status: UserStatus.disabled),
          Permission.reviewChallenges,
        ),
        isFalse,
      );
    });

    test(
      'review requires pending status, a valid reason and unexpired approval',
      () {
        final pending = challenge().copyWith(status: ChallengeStatus.pending);
        ChallengeService.validateReview(pending, now: now);
        ChallengeService.validateReview(
          pending,
          reason: 'Motif suffisant',
          now: now,
        );
        expect(
          () =>
              ChallengeService.validateReview(pending, reason: 'non', now: now),
          throwsA(isA<ChallengeException>()),
        );
        expect(
          () => ChallengeService.validateReview(
            pending,
            now: end.add(const Duration(seconds: 1)),
          ),
          throwsA(isA<ChallengeException>()),
        );
        for (final status in ChallengeStatus.values.where(
          (s) => s != ChallengeStatus.pending,
        )) {
          expect(
            () => ChallengeService.validateReview(
              pending.copyWith(status: status),
              now: now,
            ),
            throwsA(isA<ChallengeException>()),
          );
        }
      },
    );

    test('coach edits of rejected and pending challenges resubmit', () {
      expect(
        ChallengeService.needsResubmission(user(), ChallengeStatus.rejected),
        isTrue,
      );
      expect(
        ChallengeService.needsResubmission(user(), ChallengeStatus.pending),
        isTrue,
      );
      expect(
        ChallengeService.needsResubmission(user(), ChallengeStatus.active),
        isFalse,
      );
      expect(
        ChallengeService.needsResubmission(
          user(role: UserRole.admin),
          ChallengeStatus.rejected,
        ),
        isFalse,
      );
    });

    test('review fields round trip and can be cleared', () {
      final reviewed = challenge().copyWith(
        status: ChallengeStatus.rejected,
        rejectionReason: 'Motif refus',
        reviewedBy: 7,
        reviewedAt: now,
      );
      final loaded = Challenge.fromMap(reviewed.toMap());
      expect(loaded.rejectionReason, 'Motif refus');
      expect(loaded.reviewedBy, 7);
      expect(loaded.reviewedAt, now);
      final cleared = loaded.copyWith(
        rejectionReason: null,
        reviewedBy: null,
        reviewedAt: null,
      );
      expect(cleared.rejectionReason, isNull);
      expect(cleared.reviewedBy, isNull);
      expect(cleared.reviewedAt, isNull);
    });

    test('member sees only active; coach sees own and other active', () {
      final member = user(role: UserRole.member);
      final coach = user();
      for (final status in ChallengeStatus.values) {
        final own = challenge().copyWith(status: status, createdBy: 1);
        final other = challenge().copyWith(status: status, createdBy: 2);
        expect(
          ChallengeService.canViewChallenge(member, own),
          status == ChallengeStatus.active,
        );
        expect(ChallengeService.canViewChallenge(coach, own), isTrue);
        expect(
          ChallengeService.canViewChallenge(coach, other),
          status == ChallengeStatus.active,
        );
      }
    });
  });
}
