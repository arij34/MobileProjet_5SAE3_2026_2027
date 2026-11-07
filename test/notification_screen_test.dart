import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mygym/core/routes/app_routes.dart';
import 'package:mygym/core/session/session_manager.dart';
import 'package:mygym/features/challenges/models/challenge.dart';
import 'package:mygym/features/challenges/models/challenge_status.dart';
import 'package:mygym/features/challenges/services/challenge_service.dart';
import 'package:mygym/features/notifications/models/app_notification.dart';
import 'package:mygym/features/notifications/models/notification_type.dart';
import 'package:mygym/features/notifications/screens/notifications_screen.dart';
import 'package:mygym/features/notifications/services/notification_service.dart';
import 'package:mygym/features/users/models/user.dart';
import 'package:mygym/features/users/models/user_role.dart';
import 'package:mygym/features/users/screens/home_screen.dart';

class _Notifications implements NotificationService {
  _Notifications(this.items);

  List<AppNotification> items;
  @override
  final ValueNotifier<int> unreadCount = ValueNotifier(0);

  @override
  void resetUnreadCount() => unreadCount.value = 0;

  @override
  Future<void> refreshUnreadCount() async {
    unreadCount.value = items.where((item) => !item.isRead).length;
  }

  @override
  Future<List<AppNotification>> getMyNotifications({
    int limit = 50,
    int offset = 0,
  }) async => items.skip(offset).take(limit).toList();

  @override
  Future<void> markAsRead(int id) async {
    items = [
      for (final item in items)
        if (item.id == id) item.copyWith(isRead: true) else item,
    ];
    await refreshUnreadCount();
  }

  @override
  Future<void> markAllAsRead() async {
    items = [for (final item in items) item.copyWith(isRead: true)];
    await refreshUnreadCount();
  }

  @override
  Future<void> deleteNotification(int id) async {
    items.removeWhere((item) => item.id == id);
    await refreshUnreadCount();
  }

  @override
  Future<void> clearAll() async {
    items.clear();
    await refreshUnreadCount();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Challenges implements ChallengeService {
  _Challenges(this.challenge);
  final Challenge? challenge;

  @override
  Future<Challenge?> getChallengeById(int id) async => challenge;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.now();
  User user(UserRole role) => User(
    id: 1,
    firstName: 'Test',
    lastName: 'User',
    email: 'test@example.com',
    passwordHash: 'hash',
    phone: '12345678',
    role: role,
    createdAt: now,
  );
  AppNotification notification(int id, {int? challengeId = 7}) =>
      AppNotification(
        id: id,
        userId: 1,
        type: NotificationType.challengePendingReview,
        title: 'Challenge à valider $id',
        body: 'Un coach a soumis un challenge.',
        challengeId: challengeId,
        createdAt: now,
      );

  tearDown(SessionManager.instance.logout);

  for (final role in [UserRole.admin, UserRole.coach, UserRole.member]) {
    testWidgets('home notification bell and badge for $role', (tester) async {
      SessionManager.instance.currentUser = user(role);
      final service = _Notifications([notification(1), notification(2)]);
      addTearDown(service.unreadCount.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(notificationService: service),
          routes: {
            AppRoutes.notifications: (_) =>
                NotificationsScreen(service: service),
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Notifications'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.byTooltip('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Challenge à valider 1'), findsOneWidget);
      await tester.tap(find.byTooltip('Tout marquer comme lu'));
      await tester.pumpAndSettle();
      expect(service.unreadCount.value, 0);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('2'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('opening a notification marks it read and opens its challenge', (
    tester,
  ) async {
    SessionManager.instance.currentUser = user(UserRole.admin);
    final service = _Notifications([notification(1)]);
    addTearDown(service.unreadCount.dispose);
    final challenge = Challenge(
      id: 7,
      title: 'Challenge',
      xpReward: 50,
      startDate: now,
      endDate: now.add(const Duration(days: 7)),
      status: ChallengeStatus.pending,
      createdBy: 2,
      createdAt: now,
      updatedAt: now,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(
          service: service,
          challengeService: _Challenges(challenge),
        ),
        onGenerateRoute: (settings) {
          expect(settings.name, AppRoutes.challengeDetail);
          expect(settings.arguments, 7);
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Challenge ouvert')),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Challenge à valider 1'));
    await tester.pumpAndSettle();
    expect(find.text('Challenge ouvert'), findsOneWidget);
    expect(service.items.single.isRead, isTrue);
    expect(service.unreadCount.value, 0);
  });

  testWidgets('unavailable challenge and clearing notifications', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SessionManager.instance.currentUser = user(UserRole.member);
    final service = _Notifications([notification(1, challengeId: null)]);
    addTearDown(service.unreadCount.dispose);
    await tester.pumpWidget(
      MaterialApp(home: NotificationsScreen(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Challenge à valider 1'));
    await tester.pumpAndSettle();
    expect(find.text("Ce challenge n'est plus disponible"), findsOneWidget);
    await tester.tap(find.byTooltip('Tout effacer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Effacer'));
    await tester.pumpAndSettle();
    expect(find.text('Aucune notification'), findsOneWidget);
    expect(service.unreadCount.value, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping deletes only the selected notification', (tester) async {
    SessionManager.instance.currentUser = user(UserRole.admin);
    final service = _Notifications([notification(1), notification(2)]);
    addTearDown(service.unreadCount.dispose);
    await tester.pumpWidget(
      MaterialApp(home: NotificationsScreen(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.text('Challenge à valider 1'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Challenge à valider 1'), findsNothing);
    expect(find.text('Challenge à valider 2'), findsOneWidget);
    expect(service.unreadCount.value, 1);
  });
}
