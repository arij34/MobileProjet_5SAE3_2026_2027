import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mygym/core/routes/app_routes.dart';
import 'package:mygym/core/session/session_manager.dart';
import 'package:mygym/features/challenges/screens/admin_challenges_screen.dart';
import 'package:mygym/features/challenges/screens/challenges_screen.dart';
import 'package:mygym/features/challenges/screens/challenge_form_screen.dart';
import 'package:mygym/features/challenges/models/challenge.dart';
import 'package:mygym/features/challenges/models/challenge_status.dart';
import 'package:mygym/features/challenges/models/challenge_task.dart';
import 'package:mygym/features/challenges/services/challenge_service.dart';
import 'package:mygym/features/users/models/user.dart';
import 'package:mygym/features/users/models/user_role.dart';

class _AdminService implements ChallengeService {
  _AdminService(this.challenges);
  final List<Challenge> challenges;

  @override
  Future<List<Challenge>> getChallenges({
    ChallengeStatus? status,
    int? createdBy,
  }) async => challenges;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FormService implements ChallengeService {
  _FormService(this.participantCount, {this.started = false});
  final int participantCount;
  final bool started;
  final now = DateTime.now();
  Challenge? updated;
  List<ChallengeTask>? updatedTasks;

  @override
  Future<Challenge?> getChallengeById(int id) async => Challenge(
    id: id,
    title: 'Challenge test',
    xpReward: 50,
    startDate: now.add(Duration(days: started ? 0 : 1)),
    endDate: now.add(const Duration(days: 10)),
    status: ChallengeStatus.active,
    createdBy: 1,
    createdAt: now,
    updatedAt: now,
    tasks: const [
      ChallengeTask(id: 1, title: 'Première tâche', targetValue: 10),
      ChallengeTask(id: 2, title: 'Deuxième tâche', targetValue: 20),
    ],
  );

  @override
  Future<int> countParticipants(int challengeId) async => participantCount;

  @override
  Future<Challenge> updateChallenge(
    Challenge challenge,
    List<ChallengeTask> tasks,
  ) async {
    updated = challenge;
    updatedTasks = tasks;
    return challenge;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('challenge route selects the review screen for admins', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox).first);
    User signedIn(UserRole role) => User(
      id: 1,
      firstName: 'Test',
      lastName: 'User',
      email: 'test@example.com',
      passwordHash: 'hash',
      phone: '12345678',
      role: role,
      createdAt: DateTime(2026),
    );
    addTearDown(SessionManager.instance.logout);
    SessionManager.instance.currentUser = signedIn(UserRole.admin);
    expect(
      AppRoutes.routes[AppRoutes.challenges]!(context),
      isA<AdminChallengesScreen>(),
    );
    SessionManager.instance.currentUser = signedIn(UserRole.coach);
    expect(
      AppRoutes.routes[AppRoutes.challenges]!(context),
      isA<ChallengesScreen>(),
    );
  });

  testWidgets('admin tabs organize challenges by review status', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SessionManager.instance.currentUser = User(
      id: 1,
      firstName: 'Test',
      lastName: 'Admin',
      email: 'test@example.com',
      passwordHash: 'hash',
      phone: '12345678',
      role: UserRole.admin,
      createdAt: DateTime(2026),
    );
    addTearDown(SessionManager.instance.logout);
    final now = DateTime.now();
    Challenge item(String title, ChallengeStatus status) => Challenge(
      id: status.index + 1,
      title: title,
      xpReward: 50,
      startDate: now,
      endDate: now.add(const Duration(days: 10)),
      status: status,
      createdBy: 2,
      createdAt: now,
      updatedAt: now,
    );
    final service = _AdminService([
      item('Défi en attente', ChallengeStatus.pending),
      item('Défi approuvé', ChallengeStatus.active),
      item('Défi rejeté', ChallengeStatus.rejected),
      item('Défi annulé', ChallengeStatus.cancelled),
    ]);
    await tester.pumpWidget(
      MaterialApp(home: AdminChallengesScreen(service: service)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('En attente'), findsOneWidget);
    expect(find.text('Approuvés'), findsOneWidget);
    expect(find.text('Rejetés'), findsOneWidget);
    expect(find.text('Défi en attente'), findsOneWidget);
    expect(find.text('Défi approuvé'), findsNothing);
    expect(find.text('Créer le challenge'), findsNothing);

    await tester.tap(find.text('Approuvés'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Défi approuvé'), findsOneWidget);
    expect(find.text('Défi en attente'), findsNothing);
    await tester.tap(find.text('Rejetés'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Défi rejeté'), findsOneWidget);
    await tester.ensureVisible(find.text('Annulés'));
    await tester.tap(find.text('Annulés'));
    await tester.pumpAndSettle();
    expect(find.text('Défi annulé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'small-screen form keeps task controls and validation accessible',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SessionManager.instance.currentUser = User(
        id: 1,
        firstName: 'Test',
        lastName: 'Coach',
        email: 'test@example.com',
        passwordHash: 'hash',
        phone: '12345678',
        role: UserRole.coach,
        createdAt: DateTime(2026),
      );
      addTearDown(() => SessionManager.instance.currentUser = null);

      await tester.pumpWidget(const MaterialApp(home: ChallengeFormScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Nouveau challenge'), findsOneWidget);
      expect(find.text('Créer le challenge'), findsOneWidget);
      await tester.tap(find.text('Créer le challenge'));
      await tester.pumpAndSettle();
      expect(find.text('Le titre est obligatoire'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Ajouter une tâche'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Ajouter une tâche')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajouter une tâche'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Tâche 2'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Tâche 2'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final count in [0, 1]) {
    testWidgets(
      'coach edit form ${count == 0 ? 'allows' : 'locks'} task reordering',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SessionManager.instance.currentUser = User(
          id: 1,
          firstName: 'Test',
          lastName: 'Coach',
          email: 'test@example.com',
          passwordHash: 'hash',
          phone: '12345678',
          role: UserRole.coach,
          createdAt: DateTime(2026),
        );
        addTearDown(SessionManager.instance.logout);
        final service = _FormService(count);
        await tester.pumpWidget(
          MaterialApp(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              settings: const RouteSettings(arguments: 42),
              builder: (_) => ChallengeFormScreen(service: service),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Ajouter une tâche'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.takeException(), isNull);
        expect(
          find.textContaining('sont verrouillés'),
          count == 0 ? findsNothing : findsOneWidget,
        );
        final add = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'Ajouter une tâche'),
        );
        expect(add.onPressed == null, count > 0);
        expect(
          find.byType(ReorderableListView),
          count == 0 ? findsOneWidget : findsNothing,
        );
        if (count == 0) {
          final list = tester.widget<ReorderableListView>(
            find.byType(ReorderableListView),
          );
          list.onReorderItem!(0, 1);
          await tester.pumpAndSettle();
          final firstInput = tester
              .widgetList<TextFormField>(find.byType(TextFormField))
              .firstWhere(
                (input) => input.controller?.text == 'Deuxième tâche',
              );
          expect(firstInput.enabled, isNot(false));
          final fields = tester
              .widgetList<TextFormField>(find.byType(TextFormField))
              .map((input) => input.controller?.text)
              .toList();
          expect(
            fields.indexOf('Deuxième tâche'),
            lessThan(fields.indexOf('Première tâche')),
          );
        } else {
          final inputs = tester.widgetList<TextFormField>(
            find.byType(TextFormField),
          );
          expect(
            inputs
                .firstWhere(
                  (input) => input.controller?.text == 'Première tâche',
                )
                .enabled,
            isFalse,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Enregistrer'));
        await tester.pumpAndSettle();
        expect(service.updated?.title, 'Challenge test');
        expect(
          service.updatedTasks!.map((task) => task.id).toList(),
          count == 0 ? [2, 1] : [1, 2],
        );
      },
    );
  }

  for (final role in [UserRole.coach, UserRole.admin]) {
    testWidgets('started challenge form respects $role edit policy', (
      tester,
    ) async {
      SessionManager.instance.currentUser = User(
        id: 1,
        firstName: 'Test',
        lastName: 'User',
        email: 'test@example.com',
        passwordHash: 'hash',
        phone: '12345678',
        role: role,
        createdAt: DateTime(2026),
      );
      addTearDown(SessionManager.instance.logout);
      final service = _FormService(1, started: true);
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: const RouteSettings(arguments: 42),
            builder: (_) => ChallengeFormScreen(service: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (role == UserRole.coach) {
        expect(find.textContaining('ne peut plus modifier'), findsOneWidget);
        expect(find.text('Enregistrer'), findsNothing);
      } else {
        expect(find.text('Enregistrer'), findsNothing);
        expect(find.textContaining('ne peut plus modifier'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('coach selects task dates and submits them', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SessionManager.instance.currentUser = User(
      id: 1,
      firstName: 'Test',
      lastName: 'Coach',
      email: 'test@example.com',
      passwordHash: 'hash',
      phone: '12345678',
      role: UserRole.coach,
      createdAt: DateTime(2026),
    );
    addTearDown(SessionManager.instance.logout);
    final service = _FormService(0);
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: const RouteSettings(arguments: 42),
          builder: (_) => ChallengeFormScreen(service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Ajouter une tâche'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -450));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter une date').first);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Dates prévues (objectif total partagé)'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(service.updatedTasks!.first.scheduledDates, hasLength(1));
    final date = service.updatedTasks!.first.scheduledDates.single;
    final start = service.now.add(const Duration(days: 1));
    expect(
      [date.year, date.month, date.day],
      [start.year, start.month, start.day],
    );
  });
}
