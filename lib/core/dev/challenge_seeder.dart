import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/challenges/models/challenge.dart';
import '../../features/challenges/models/challenge_difficulty.dart';
import '../../features/challenges/models/challenge_status.dart';
import '../../features/challenges/models/challenge_table.dart';
import '../../features/challenges/models/challenge_task.dart';
import '../../features/challenges/models/challenge_type.dart';
import '../../features/challenges/models/challenge_unit.dart';
import '../../features/challenges/services/challenge_service.dart';
import '../../features/users/models/user_role.dart';
import '../../features/users/models/user_status.dart';
import '../../features/users/models/user_table.dart';
import '../database/database_helper.dart';
import '../session/session_manager.dart';

class ChallengeSeeder {
  ChallengeSeeder._() : _database = (() => DatabaseHelper.instance.database);

  @visibleForTesting
  ChallengeSeeder.forDatabase(Future<Database> Function() database)
    : _database = database;

  static final ChallengeSeeder instance = ChallengeSeeder._();
  final Future<Database> Function() _database;

  int _currentCoachId() {
    final user = SessionManager.instance.currentUser;
    if (!kDebugMode ||
        user == null ||
        !user.isActive ||
        user.role != UserRole.coach ||
        user.id == null) {
      throw const ChallengeException('Réservé aux coachs actifs');
    }
    return user.id!;
  }

  void _checkCoach(int coachId) {
    if (_currentCoachId() != coachId) {
      throw const ChallengeException('La session a changé');
    }
  }

  Future<int> seedDemoChallenges() async {
    final coachId = _currentCoachId();
    final db = await _database();
    return db.transaction((txn) async {
      _checkCoach(coachId);
      final admins = await txn.query(
        UserTable.tableName,
        columns: [UserTable.colId],
        where: '${UserTable.colRole} = ? AND ${UserTable.colStatus} = ?',
        whereArgs: [UserRole.admin.value, UserStatus.active.value],
        orderBy: UserTable.colId,
        limit: 1,
      );
      final adminId = admins.isEmpty
          ? null
          : admins.first[UserTable.colId] as int;
      final now = DateTime.now();
      var inserted = 0;
      for (final demo in _demoChallenges) {
        final existing = await txn.query(
          ChallengeTable.tableName,
          columns: [ChallengeTable.colId],
          where:
              '${ChallengeTable.colTitle} = ? AND ${ChallengeTable.colCreatedBy} = ?',
          whereArgs: [demo.title, coachId],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;

        final start = DateTime(now.year, now.month, now.day + demo.offset);
        final end = DateTime(
          start.year,
          start.month,
          start.day + demo.duration,
          23,
          59,
          59,
        );
        final isReviewed =
            demo.status == ChallengeStatus.active ||
            demo.status == ChallengeStatus.rejected;
        final challenge = Challenge(
          title: demo.title,
          description: demo.description,
          difficulty: demo.difficulty,
          xpReward: demo.xp,
          status: demo.status,
          startDate: start,
          endDate: end,
          createdBy: coachId,
          createdAt: now,
          updatedAt: now,
          rejectionReason: demo.rejectionReason,
          reviewedBy: isReviewed ? adminId : null,
          reviewedAt:
              isReviewed &&
                  (adminId != null || demo.status == ChallengeStatus.rejected)
              ? now
              : null,
        );
        ChallengeService.validate(
          challenge,
          demo.tasks,
          now: now,
          validateStartDate: false,
        );
        final id = await txn.insert(
          ChallengeTable.tableName,
          challenge.toMap(),
        );
        for (var i = 0; i < demo.tasks.length; i++) {
          await txn.insert(
            ChallengeTaskTable.tableName,
            demo.tasks[i].copyWith(challengeId: id, orderIndex: i).toMap(),
          );
        }
        inserted++;
      }
      _checkCoach(coachId);
      return inserted;
    });
  }

  Future<int> removeDemoChallenges() async {
    final coachId = _currentCoachId();
    final db = await _database();
    final placeholders = List.filled(_demoChallenges.length, '?').join(', ');
    return db.transaction((txn) async {
      _checkCoach(coachId);
      final removed = await txn.delete(
        ChallengeTable.tableName,
        where:
            '${ChallengeTable.colTitle} IN ($placeholders) AND ${ChallengeTable.colCreatedBy} = ?',
        whereArgs: [..._demoChallenges.map((demo) => demo.title), coachId],
      );
      _checkCoach(coachId);
      return removed;
    });
  }
}

class _Demo {
  final String title;
  final ChallengeDifficulty difficulty;
  final int xp;
  final ChallengeStatus status;
  final int offset;
  final int duration;
  final String description;
  final List<ChallengeTask> tasks;
  final String? rejectionReason;

  const _Demo(
    this.title,
    this.difficulty,
    this.xp,
    this.status,
    this.offset,
    this.duration,
    this.description,
    this.tasks, {
    this.rejectionReason,
  });
}

const _demoChallenges = <_Demo>[
  _Demo(
    'Reprise en douceur',
    ChallengeDifficulty.easy,
    50,
    ChallengeStatus.active,
    -2,
    14,
    "Un programme progressif pour reprendre l'activité physique sans se blesser : marche, mobilité et renforcement léger.",
    [
      ChallengeTask(
        title: 'Marcher 50 000 pas au total',
        type: ChallengeType.steps,
        unit: ChallengeUnit.steps,
        targetValue: 50000,
        description:
            'Cumulez vos pas sur la durée du challenge, en plusieurs sorties.',
      ),
      ChallengeTask(
        title: "Séances d'étirements",
        type: ChallengeType.flexibility,
        unit: ChallengeUnit.minutes,
        targetValue: 60,
        description:
            'Étirez le dos, les hanches et les jambes après vos marches.',
      ),
      ChallengeTask(
        title: 'Squats au poids du corps',
        type: ChallengeType.workout,
        unit: ChallengeUnit.reps,
        targetValue: 150,
        description:
            'Répartissez-les sur plusieurs jours, en gardant le dos droit.',
      ),
      ChallengeTask(
        title: 'Pompes sur les genoux',
        type: ChallengeType.workout,
        unit: ChallengeUnit.reps,
        targetValue: 80,
        description: 'Privilégiez une bonne posture plutôt que la vitesse.',
      ),
    ],
  ),
  _Demo(
    'Objectif 50 km course à pied',
    ChallengeDifficulty.medium,
    100,
    ChallengeStatus.active,
    -5,
    30,
    'Montez progressivement en charge et franchissez la barre des 50 km en un mois, avec de la récupération intégrée.',
    [
      ChallengeTask(
        title: 'Courir 50 km cumulés',
        type: ChallengeType.running,
        unit: ChallengeUnit.km,
        targetValue: 50,
        description: 'Au moins 3 sorties par semaine, à allure modérée.',
      ),
      ChallengeTask(
        title: 'Réaliser une sortie longue',
        type: ChallengeType.running,
        unit: ChallengeUnit.km,
        targetValue: 10,
        description: 'Une seule sortie, à allure confortable.',
      ),
      ChallengeTask(
        title: 'Footing de récupération',
        type: ChallengeType.running,
        unit: ChallengeUnit.minutes,
        targetValue: 120,
        description: 'Allure lente, vous devez pouvoir parler en courant.',
      ),
      ChallengeTask(
        title: 'Étirements post-course',
        type: ChallengeType.flexibility,
        unit: ChallengeUnit.minutes,
        targetValue: 60,
        description: 'Mollets, ischio-jambiers, quadriceps et fessiers.',
      ),
    ],
  ),
  _Demo(
    'Force : 1000 pompes',
    ChallengeDifficulty.hard,
    250,
    ChallengeStatus.active,
    -3,
    21,
    'Un défi de volume pour développer la force du haut du corps : 1000 pompes en trois semaines.',
    [
      ChallengeTask(
        title: 'Pompes classiques',
        type: ChallengeType.workout,
        unit: ChallengeUnit.reps,
        targetValue: 600,
        description: 'Poitrine proche du sol, corps gainé.',
      ),
      ChallengeTask(
        title: 'Pompes diamant',
        type: ChallengeType.workout,
        unit: ChallengeUnit.reps,
        targetValue: 200,
        description: 'Mains rapprochées pour cibler les triceps.',
      ),
      ChallengeTask(
        title: 'Pompes larges',
        type: ChallengeType.workout,
        unit: ChallengeUnit.reps,
        targetValue: 200,
        description: 'Mains plus écartées que les épaules.',
      ),
      ChallengeTask(
        title: 'Gainage planche',
        type: ChallengeType.workout,
        unit: ChallengeUnit.minutes,
        targetValue: 30,
        description: 'Cumulez le temps de tenue sur toutes les séances.',
      ),
      ChallengeTask(
        title: 'Étirements pectoraux et épaules',
        type: ChallengeType.flexibility,
        unit: ChallengeUnit.minutes,
        targetValue: 45,
        description: 'Après chaque séance de pompes.',
      ),
    ],
  ),
  _Demo(
    'Mobilité et souplesse',
    ChallengeDifficulty.easy,
    60,
    ChallengeStatus.active,
    3,
    14,
    'Gagnez en amplitude et réduisez les tensions grâce à une routine quotidienne de mobilité.',
    [
      ChallengeTask(
        title: 'Routine de mobilité matinale',
        type: ChallengeType.flexibility,
        unit: ChallengeUnit.minutes,
        targetValue: 140,
        description: '10 minutes par jour pendant deux semaines.',
      ),
      ChallengeTask(
        title: 'Étirements des hanches',
        type: ChallengeType.flexibility,
        unit: ChallengeUnit.minutes,
        targetValue: 60,
        description: 'Fentes basses, pigeon et papillon.',
      ),
      ChallengeTask(
        title: 'Étirements du dos et des épaules',
        type: ChallengeType.flexibility,
        unit: ChallengeUnit.minutes,
        targetValue: 60,
        description: "Posture de l'enfant, rotations thoraciques.",
      ),
      ChallengeTask(
        title: 'Marche tranquille',
        type: ChallengeType.steps,
        unit: ChallengeUnit.steps,
        targetValue: 30000,
        description: 'Pour activer la circulation entre les séances.',
      ),
    ],
  ),
  _Demo(
    '10 000 pas par jour',
    ChallengeDifficulty.medium,
    120,
    ChallengeStatus.active,
    -9,
    10,
    "Adoptez l'habitude de marcher chaque jour pour améliorer votre énergie et votre santé cardiovasculaire.",
    [
      ChallengeTask(
        title: 'Atteindre 100 000 pas au total',
        type: ChallengeType.steps,
        unit: ChallengeUnit.steps,
        targetValue: 100000,
        description: 'Soit environ 10 000 pas par jour.',
      ),
      ChallengeTask(
        title: 'Marche rapide',
        type: ChallengeType.running,
        unit: ChallengeUnit.minutes,
        targetValue: 150,
        description: 'Allure soutenue, respiration légèrement accélérée.',
      ),
      ChallengeTask(
        title: 'Marcher 20 km au total',
        type: ChallengeType.running,
        unit: ChallengeUnit.km,
        targetValue: 20,
        description: 'Parcours variés : parc, quartier, bord de mer.',
      ),
    ],
  ),
  _Demo(
    'Cardio brûle-calories',
    ChallengeDifficulty.medium,
    150,
    ChallengeStatus.active,
    -45,
    30,
    "Un mois de cardio varié pour dépenser de l'énergie et améliorer votre endurance.",
    [
      ChallengeTask(
        title: 'Dépense cumulée de 5000 kcal',
        type: ChallengeType.workout,
        unit: ChallengeUnit.kcal,
        targetValue: 5000,
        description: 'Suivez la dépense avec votre montre ou une application.',
      ),
      ChallengeTask(
        title: 'Séances de corde à sauter',
        type: ChallengeType.workout,
        unit: ChallengeUnit.minutes,
        targetValue: 90,
        description: 'Séries de 2 minutes avec 1 minute de repos.',
      ),
      ChallengeTask(
        title: 'Vélo ou vélo elliptique',
        type: ChallengeType.workout,
        unit: ChallengeUnit.minutes,
        targetValue: 240,
        description: 'À intensité modérée.',
      ),
      ChallengeTask(
        title: 'Burpees',
        type: ChallengeType.workout,
        unit: ChallengeUnit.reps,
        targetValue: 300,
        description: 'Répartis en séries de 15 à 20.',
      ),
    ],
  ),
  _Demo(
    'Alimentation équilibrée en 3 semaines',
    ChallengeDifficulty.medium,
    140,
    ChallengeStatus.active,
    -1,
    21,
    'Structurez vos repas autour de protéines, légumes et féculents complets, sans régime restrictif.',
    [
      ChallengeTask(
        title: 'Petits-déjeuners équilibrés (~400 kcal)',
        type: ChallengeType.nutrition,
        unit: ChallengeUnit.kcal,
        targetValue: 8400,
        description:
            '21 petits-déjeuners avec protéines, fibres et bons lipides.',
      ),
      ChallengeTask(
        title: 'Repas maison riches en protéines (~600 kcal)',
        type: ChallengeType.nutrition,
        unit: ChallengeUnit.kcal,
        targetValue: 6000,
        description: '10 déjeuners ou dîners préparés à la maison.',
      ),
      ChallengeTask(
        title: "Préparer vos repas à l'avance",
        type: ChallengeType.nutrition,
        unit: ChallengeUnit.minutes,
        targetValue: 180,
        description: 'Séances de meal prep le week-end.',
      ),
      ChallengeTask(
        title: 'Marche digestive après le repas',
        type: ChallengeType.steps,
        unit: ChallengeUnit.steps,
        targetValue: 30000,
        description: '10 à 15 minutes après les repas principaux.',
      ),
    ],
  ),
  _Demo(
    'Gainage et abdos : cœur solide',
    ChallengeDifficulty.hard,
    200,
    ChallengeStatus.pending,
    5,
    28,
    'Renforcez la sangle abdominale et le bas du dos pour une meilleure posture et moins de douleurs.',
    [
      ChallengeTask(
        title: 'Planche',
        type: ChallengeType.workout,
        unit: ChallengeUnit.minutes,
        targetValue: 60,
        description:
            'Cumulez le temps de tenue, par séries de 30 à 90 secondes.',
      ),
      ChallengeTask(
        title: 'Relevés de buste',
        type: ChallengeType.workout,
        unit: ChallengeUnit.reps,
        targetValue: 500,
        description: 'Mouvement contrôlé, sans tirer sur la nuque.',
      ),
      ChallengeTask(
        title: 'Relevés de jambes',
        type: ChallengeType.workout,
        unit: ChallengeUnit.reps,
        targetValue: 300,
        description: 'Bas du dos plaqué au sol.',
      ),
      ChallengeTask(
        title: 'Planche latérale',
        type: ChallengeType.workout,
        unit: ChallengeUnit.minutes,
        targetValue: 30,
        description: 'Autant à gauche qu\'à droite.',
      ),
      ChallengeTask(
        title: 'Étirements du dos',
        type: ChallengeType.flexibility,
        unit: ChallengeUnit.minutes,
        targetValue: 60,
        description: 'Après chaque séance.',
      ),
    ],
  ),
  _Demo(
    'Triathlon à la maison',
    ChallengeDifficulty.hard,
    400,
    ChallengeStatus.pending,
    7,
    30,
    'Enchaînez trois disciplines en un mois : endurance, force et récupération.',
    [
      ChallengeTask(
        title: 'Courir 30 km',
        type: ChallengeType.running,
        unit: ChallengeUnit.km,
        targetValue: 30,
        description: 'Réparti sur au moins 4 sorties.',
      ),
      ChallengeTask(
        title: 'Séances de renforcement musculaire',
        type: ChallengeType.workout,
        unit: ChallengeUnit.minutes,
        targetValue: 240,
        description: 'Circuit complet corps entier.',
      ),
      ChallengeTask(
        title: 'Pompes',
        type: ChallengeType.workout,
        unit: ChallengeUnit.reps,
        targetValue: 400,
        description: 'Séries de 20 à 25.',
      ),
      ChallengeTask(
        title: 'Squats sautés',
        type: ChallengeType.workout,
        unit: ChallengeUnit.reps,
        targetValue: 300,
        description: 'Réception souple, genoux alignés.',
      ),
      ChallengeTask(
        title: 'Étirements et mobilité',
        type: ChallengeType.flexibility,
        unit: ChallengeUnit.minutes,
        targetValue: 120,
        description: 'Pour récupérer entre les séances.',
      ),
      ChallengeTask(
        title: 'Marche de récupération',
        type: ChallengeType.steps,
        unit: ChallengeUnit.steps,
        targetValue: 60000,
        description: 'Les jours de repos actif.',
      ),
    ],
  ),
  _Demo(
    'Défi abdos express',
    ChallengeDifficulty.easy,
    50,
    ChallengeStatus.rejected,
    2,
    7,
    'Une semaine pour tester vos abdominaux avec des exercices rapides.',
    [
      ChallengeTask(
        title: 'Crunchs',
        type: ChallengeType.workout,
        unit: ChallengeUnit.reps,
        targetValue: 200,
        description: 'Mouvement lent et contrôlé.',
      ),
      ChallengeTask(
        title: 'Planche',
        type: ChallengeType.workout,
        unit: ChallengeUnit.minutes,
        targetValue: 15,
        description: 'Cumulez le temps de tenue.',
      ),
    ],
    rejectionReason: 'Les consignes sont trop courtes. Précisez le niveau requis, le nombre de séances par semaine et les précautions pour le dos, puis soumettez à nouveau.',
  ),
  _Demo(
    'Challenge de printemps',
    ChallengeDifficulty.medium,
    100,
    ChallengeStatus.cancelled,
    -20,
    20,
    "Challenge annulé par manque de participants, conservé pour l'historique.",
    [
      ChallengeTask(
        title: 'Courir 25 km',
        type: ChallengeType.running,
        unit: ChallengeUnit.km,
        targetValue: 25,
        description: 'Sorties régulières.',
      ),
      ChallengeTask(
        title: 'Séances de gainage',
        type: ChallengeType.workout,
        unit: ChallengeUnit.minutes,
        targetValue: 40,
        description: 'Cumulé.',
      ),
    ],
  ),
];
