import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mygym/core/routes/app_routes.dart';
import 'package:mygym/core/session/session_manager.dart';
import 'package:mygym/features/challenges/models/challenge_difficulty.dart';
import 'package:mygym/features/challenges/models/challenge_status.dart';
import 'package:mygym/features/challenges/models/challenge_type.dart';
import 'package:mygym/features/challenges/models/challenge_unit.dart';
import 'package:mygym/features/challenges/screens/ai_challenge_screen.dart';
import 'package:mygym/features/challenges/screens/challenge_form_screen.dart';
import 'package:mygym/features/challenges/services/ai_challenge_generator.dart';
import 'package:mygym/features/users/models/user.dart';
import 'package:mygym/features/users/models/user_role.dart';

void main() {
  final now = DateTime(2026, 11, 6, 15, 30);
  AiChallengeRequest request({
    int count = 2,
    String instructions = '',
    List<AiFocusArea> areas = const [AiFocusArea.biceps],
  }) => AiChallengeRequest(
    difficulty: ChallengeDifficulty.medium,
    durationDays: 14,
    taskCount: count,
    focusAreas: areas,
    extraInstructions: instructions,
  );
  Map<String, Object> task({
    String type = 'workout',
    String unit = 'reps',
    num target = 200,
  }) => {
    'title': 'Curl biceps',
    'description': 'Gardez le dos droit.',
    'type': type,
    'unit': unit,
    'targetValue': target,
  };
  String envelope(List<Map<String, Object>> tasks) => jsonEncode({
    'choices': [
      {
        'message': {
          'content': jsonEncode({
            'title': 'Force progressive',
            'description': 'Un entraînement progressif.',
            'tasks': tasks,
          }),
        },
      },
    ],
  });
  AiChallengeGenerator generator(
    Future<http.Response> Function(http.Request) handler, {
    String key = 'test-placeholder',
    Duration cooldown = Duration.zero,
  }) => AiChallengeGenerator.forTesting(
    client: MockClient(handler),
    apiKey: key,
    now: () => now,
    cooldown: cooldown,
  );
  final invalid = throwsA(isA<AiChallengeException>());

  test('valid JSON maps a draft and sends a strict schema', () async {
    final service = generator((httpRequest) async {
      expect(httpRequest.url.host, 'api.openai.com');
      expect(httpRequest.headers['authorization'], 'Bearer test-placeholder');
      final body = jsonDecode(httpRequest.body) as Map<String, dynamic>;
      final format = body['response_format'] as Map<String, dynamic>;
      expect(format['type'], 'json_schema');
      expect(format['json_schema']['strict'], true);
      return http.Response(envelope([task(), task()]), 200);
    });
    final draft = await service.generateChallenge(request());
    expect(draft.id, isNull);
    expect(draft.createdBy, 0);
    expect(draft.status, ChallengeStatus.draft);
    expect(draft.title, 'Force progressive');
    expect(draft.difficulty, ChallengeDifficulty.medium);
    expect(draft.xpReward, ChallengeDifficulty.medium.defaultXp);
    expect(draft.startDate, DateTime(2026, 11, 6));
    expect(draft.endDate, DateTime(2026, 11, 20, 23, 59, 59));
    expect(draft.tasks.length, 2);
    expect(draft.tasks.first.type, ChallengeType.workout);
    expect(draft.tasks.first.unit, ChallengeUnit.reps);
    expect(draft.tasks.first.targetValue, 200);
    expect(draft.tasks.map((t) => t.orderIndex), [0, 1]);
  });

  for (final badTask in [
    task(type: 'invalid'),
    task(unit: 'invalid'),
    task(target: 1000000),
    task(type: 'running', unit: 'km'),
  ]) {
    test('invalid task $badTask is rejected after retry', () async {
      var calls = 0;
      final service = generator((_) async {
        calls++;
        return http.Response(envelope([badTask, task()]), 200);
      });
      await expectLater(service.generateChallenge(request()), invalid);
      expect(calls, 2);
    });
  }

  test('wrong count retries once and then fails', () async {
    var calls = 0;
    final service = generator((_) async {
      calls++;
      return http.Response(envelope([task()]), 200);
    });
    await expectLater(service.generateChallenge(request()), invalid);
    expect(calls, 2);
  });

  test('invalid JSON retries and can recover', () async {
    var calls = 0;
    final service = generator((_) async {
      calls++;
      return http.Response(
        calls == 1 ? 'invalid' : envelope([task(), task()]),
        200,
      );
    });
    expect((await service.generateChallenge(request())).tasks.length, 2);
    expect(calls, 2);
  });

  test('retry tells the model the requested task count was invalid', () async {
    var calls = 0;
    final service = generator((httpRequest) async {
      calls++;
      final body = jsonDecode(httpRequest.body) as Map<String, dynamic>;
      final userContent = jsonDecode(
        (body['messages'] as List).last['content'] as String,
      ) as Map<String, dynamic>;
      if (calls == 1) {
        expect(userContent.containsKey('correction'), isFalse);
        return http.Response(envelope([task()]), 200);
      }
      expect(userContent['correction'], contains('nombre de tâches'));
      return http.Response(envelope([task(), task()]), 200);
    });
    expect((await service.generateChallenge(request())).tasks.length, 2);
    expect(calls, 2);
  });

  test('refusal is reported without exposing response content', () async {
    final service = generator(
      (_) async => http.Response(
        jsonEncode({
          'choices': [
            {
              'finish_reason': 'stop',
              'message': {'refusal': 'private refusal text', 'content': null},
            },
          ],
        }),
        200,
      ),
    );
    await expectLater(
      service.generateChallenge(request()),
      throwsA(
        isA<AiChallengeException>().having(
          (e) => e.message,
          'message',
          contains('n’a pas pu générer'),
        ),
      ),
    );
  });

  test('truncated response is retried and reported clearly', () async {
    var calls = 0;
    final service = generator((_) async {
      calls++;
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'finish_reason': 'length',
              'message': {'content': null},
            },
          ],
        }),
        200,
      );
    });
    await expectLater(
      service.generateChallenge(request()),
      throwsA(
        isA<AiChallengeException>().having(
          (e) => e.message,
          'message',
          contains('tronquée'),
        ),
      ),
    );
    expect(calls, 2);
  });

  test('missing key and long instructions do not call the network', () async {
    final service = generator((_) async {
      fail('Network must not be called');
    }, key: '');
    await expectLater(
      service.generateChallenge(request()),
      throwsA(
        isA<AiChallengeException>().having(
          (e) => e.message,
          'message',
          'Clé OpenAI non configurée',
        ),
      ),
    );
    await expectLater(
      service.generateChallenge(request(instructions: 'x' * 201)),
      throwsA(
        isA<AiChallengeException>().having(
          (e) => e.message,
          'message',
          contains('200'),
        ),
      ),
    );
  });

  for (final entry in {
    401: 'invalide',
    429: 'quota',
    503: 'indisponible',
  }.entries) {
    test('HTTP ${entry.key} displays a French error', () async {
      final service = generator((_) async => http.Response('', entry.key));
      await expectLater(
        service.generateChallenge(request()),
        throwsA(
          isA<AiChallengeException>().having(
            (e) => e.message,
            'message',
            contains(entry.value),
          ),
        ),
      );
    });
  }

  test('timeout displays a French error', () async {
    final service = generator((_) async => throw TimeoutException('test'));
    await expectLater(
      service.generateChallenge(request()),
      throwsA(
        isA<AiChallengeException>().having(
          (e) => e.message,
          'message',
          contains('expiré'),
        ),
      ),
    );
  });

  test('cooldown and concurrent submission are blocked', () async {
    final response = Completer<http.Response>();
    var calls = 0;
    final service = generator((_) {
      calls++;
      return response.future;
    }, cooldown: const Duration(seconds: 10));
    final first = service.generateChallenge(request());
    await expectLater(
      service.generateChallenge(request()),
      throwsA(isA<AiChallengeException>()),
    );
    response.complete(http.Response(envelope([task(), task()]), 200));
    await first;
    await expectLater(
      service.generateChallenge(request()),
      throwsA(isA<AiChallengeException>()),
    );
    expect(calls, 1);
  });

  testWidgets('generator opens an editable draft without saving it', (
    tester,
  ) async {
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
      createdAt: now,
    );
    addTearDown(SessionManager.instance.logout);
    final service = generator(
      (_) async =>
          http.Response(envelope(List.generate(5, (_) => task())), 200),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AiChallengeScreen(generator: service),
        routes: {AppRoutes.challengeForm: (_) => const ChallengeFormScreen()},
      ),
    );
    await tester.tap(find.text('Biceps'));
    await tester.tap(find.text('Générer'));
    await tester.pumpAndSettle();
    expect(
      find.text('Généré par IA : relisez et modifiez avant de publier'),
      findsOneWidget,
    );
    expect(find.text('Force progressive'), findsOneWidget);
    expect(find.text('Créer le challenge'), findsOneWidget);
    expect(find.text('Enregistrer'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Tâche 5'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tâche 5'), findsOneWidget);
    expect(find.text('Curl biceps'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('members cannot use the generator screen', (tester) async {
    SessionManager.instance.currentUser = User(
      id: 2,
      firstName: 'Test',
      lastName: 'Member',
      email: 'test@example.com',
      passwordHash: 'hash',
      phone: '12345678',
      role: UserRole.member,
      createdAt: now,
    );
    addTearDown(SessionManager.instance.logout);
    await tester.pumpWidget(const MaterialApp(home: AiChallengeScreen()));
    expect(
      find.text('Vous n’avez pas accès à cette fonctionnalité.'),
      findsOneWidget,
    );
    expect(find.text('Générer'), findsNothing);
  });
}
