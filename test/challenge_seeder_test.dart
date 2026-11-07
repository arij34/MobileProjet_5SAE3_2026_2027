import 'package:flutter_test/flutter_test.dart';
import 'package:mygym/core/dev/challenge_seeder.dart';
import 'package:mygym/core/session/session_manager.dart';
import 'package:mygym/features/challenges/models/challenge.dart';
import 'package:mygym/features/challenges/models/challenge_status.dart';
import 'package:mygym/features/challenges/models/challenge_task.dart';
import 'package:mygym/features/challenges/services/challenge_service.dart';
import 'package:mygym/features/users/models/user.dart';
import 'package:mygym/features/users/models/user_role.dart';
import 'package:mygym/features/users/models/user_status.dart';
import 'package:sqflite/sqflite.dart';

class _DatabaseFake implements Database, Transaction {
  final List<Map<String, Object?>> users = [];
  final List<Map<String, Object?>> challenges = [];
  final List<Map<String, Object?>> tasks = [];
  int nextId = 1;

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) => action(this);

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (table == 'users') {
      expect(where, 'role = ? AND status = ?');
      final result = users
          .where(
            (u) => u['role'] == whereArgs![0] && u['status'] == whereArgs[1],
          )
          .toList();
      return limit == null ? result : result.take(limit).toList();
    }
    expect(table, 'challenges');
    expect(where, 'title = ? AND created_by = ?');
    return challenges
        .where(
          (c) => c['title'] == whereArgs![0] && c['created_by'] == whereArgs[1],
        )
        .take(1)
        .toList();
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final id = nextId++;
    final row = {...values, 'id': id};
    if (table == 'challenges') {
      challenges.add(row);
    } else {
      expect(table, 'challenge_tasks');
      tasks.add(row);
    }
    return id;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    expect(table, 'challenges');
    expect(where, contains('AND created_by = ?'));
    final ids = challenges
        .where(
          (c) =>
              whereArgs!.take(whereArgs.length - 1).contains(c['title']) &&
              c['created_by'] == whereArgs.last,
        )
        .map((c) => c['id'])
        .toSet();
    challenges.removeWhere((c) => ids.contains(c['id']));
    tasks.removeWhere((t) => ids.contains(t['challenge_id']));
    return ids.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  User user(int? id, UserRole role, {UserStatus status = UserStatus.active}) =>
      User(
        id: id,
        firstName: 'Test',
        lastName: 'User',
        email: 'test@example.com',
        passwordHash: 'hash',
        phone: '12345678',
        role: role,
        status: status,
        createdAt: DateTime(2026),
      );
  late _DatabaseFake db;
  late ChallengeSeeder seeder;
  setUp(() {
    db = _DatabaseFake();
    seeder = ChallengeSeeder.forDatabase(() async => db);
    SessionManager.instance.currentUser = user(1, UserRole.coach);
  });
  tearDown(() => SessionManager.instance.logout());

  test('seed is idempotent and removes only matching titles', () async {
    db.users.addAll([
      {'id': 1, 'role': 'coach', 'status': 'active'},
      {'id': 2, 'role': 'coach', 'status': 'active'},
      {'id': 3, 'role': 'admin', 'status': 'active'},
      {'id': 4, 'role': 'coach', 'status': 'disabled'},
    ]);
    db.challenges.add({'id': 999, 'title': 'Challenge personnel'});
    expect(await seeder.seedDemoChallenges(), 11);
    expect(await seeder.seedDemoChallenges(), 0);
    expect(db.challenges.length, 12);
    final demos = db.challenges
        .where((c) => c['id'] != 999)
        .map(Challenge.fromMap)
        .toList();
    expect(demos.where((c) => c.status == ChallengeStatus.active).length, 7);
    expect(demos.where((c) => c.status == ChallengeStatus.pending).length, 2);
    expect(demos.where((c) => c.status == ChallengeStatus.rejected).length, 1);
    expect(demos.where((c) => c.status == ChallengeStatus.cancelled).length, 1);
    expect(demos.every((c) => c.createdBy == 1), isTrue);
    for (final challenge in demos) {
      final tasks = db.tasks
          .where((t) => t['challenge_id'] == challenge.id)
          .map(ChallengeTask.fromMap)
          .toList();
      ChallengeService.validate(challenge, tasks, validateStartDate: false);
      expect(
        tasks.map((t) => t.orderIndex),
        List.generate(tasks.length, (i) => i),
      );
      expect(tasks.every((t) => t.xpReward == 0), isTrue);
      expect(challenge.imagePath, isNull);
      expect(challenge.startDate.hour, 0);
      expect(challenge.endDate.hour, 23);
      if (challenge.status == ChallengeStatus.pending) {
        expect(challenge.reviewedBy, isNull);
        expect(challenge.reviewedAt, isNull);
      } else if (challenge.status == ChallengeStatus.active ||
          challenge.status == ChallengeStatus.rejected) {
        expect(challenge.reviewedBy, 3);
        expect(challenge.reviewedAt, isNotNull);
      }
    }
    SessionManager.instance.currentUser = user(2, UserRole.coach);
    expect(await seeder.seedDemoChallenges(), 11);
    expect(await seeder.seedDemoChallenges(), 0);
    final otherIds = db.challenges
        .where((c) => c['created_by'] == 2)
        .map((c) => c['id'])
        .toSet();
    SessionManager.instance.currentUser = user(1, UserRole.coach);
    expect(await seeder.removeDemoChallenges(), 11);
    expect(db.challenges.length, 12);
    expect(db.challenges.where((c) => c['created_by'] == 2).length, 11);
    expect(
      db.challenges.any((c) => c['title'] == 'Challenge personnel'),
      isTrue,
    );
    expect(db.tasks.every((t) => otherIds.contains(t['challenge_id'])), isTrue);
    expect(db.tasks, isNotEmpty);
    expect(await seeder.removeDemoChallenges(), 0);
  });

  test('only an active signed-in coach can seed or remove', () async {
    final denied = [
      user(3, UserRole.admin),
      user(4, UserRole.member),
      user(5, UserRole.coach, status: UserStatus.disabled),
      user(null, UserRole.coach),
      null,
    ];
    for (final current in denied) {
      SessionManager.instance.currentUser = current;
      final exception = throwsA(
        isA<ChallengeException>().having(
          (e) => e.toString(),
          'message',
          contains('Réservé aux coachs actifs'),
        ),
      );
      await expectLater(seeder.seedDemoChallenges(), exception);
      await expectLater(seeder.removeDemoChallenges(), exception);
    }
    expect(db.challenges, isEmpty);
    expect(db.tasks, isEmpty);
  });
}
