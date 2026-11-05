import 'dart:math';

import 'package:latlong2/latlong.dart';

import '../../users/models/user_goal.dart';
import '../models/equipment_category.dart';
import '../models/gym.dart';
import '../models/gym_equipment.dart';
import '../models/gym_status.dart';
import 'geo_utils.dart';
import 'gym_ai_service.dart';
import 'gym_equipment_service.dart';
import 'gym_service.dart';

/// Ce que l'adhérent a rempli dans le formulaire.
class RecommendationCriteria {
  final UserGoal goal;
  final double maxBudget; // DT par mois
  final String? city; // renseignée si l'adhérent choisit une ville
  final LatLng? position; // renseignée si l'adhérent utilise sa position

  const RecommendationCriteria({
    required this.goal,
    required this.maxBudget,
    this.city,
    this.position,
  });
}

/// Une salle recommandée avec son score et son explication.
class GymRecommendation {
  final Gym gym;
  final int fitPercent; // 0 à 100
  final double? distanceKm;
  final bool withinBudget;
  final Map<EquipmentCategory, int> usableByCategory; // quantités utilisables
  final int usableEquipment;
  final int totalEquipment;
  String explanation;

  GymRecommendation({
    required this.gym,
    required this.fitPercent,
    required this.distanceKm,
    required this.withinBudget,
    required this.usableByCategory,
    required this.usableEquipment,
    required this.totalEquipment,
    this.explanation = '',
  });
}

class RecommendationResult {
  final List<GymRecommendation> items; // la meilleure en premier
  final bool aiUsed; // false = plan B local
  final String? summary;
  final bool noneWithinBudget;

  const RecommendationResult({
    required this.items,
    required this.aiUsed,
    this.summary,
    required this.noneWithinBudget,
  });
}

/// Recommandation en deux temps :
/// 1) score calculé en Dart (budget, lieu, objectif, état des équipements) ;
/// 2) l'IA explique les 3 meilleures ; si elle échoue, explication locale.
class GymRecommendationService {
  GymRecommendationService._();
  static final GymRecommendationService instance =
      GymRecommendationService._();

  static String goalLabel(UserGoal goal) {
    switch (goal) {
      case UserGoal.gainMuscle:
        return 'Masse musculaire';
      case UserGoal.stayFit:
        return 'Bien-être';
      case UserGoal.loseWeight:
        return 'Perdre du poids';
      case UserGoal.endurance:
        return 'Endurance';
    }
  }

  /// Importance de chaque catégorie d'équipements selon l'objectif.
  static const Map<UserGoal, Map<EquipmentCategory, double>> _weights = {
    UserGoal.gainMuscle: {
      EquipmentCategory.strength: 1.0,
      EquipmentCategory.functional: 0.4,
      EquipmentCategory.cardio: 0.2,
      EquipmentCategory.groupClasses: 0.1,
    },
    UserGoal.loseWeight: {
      EquipmentCategory.cardio: 1.0,
      EquipmentCategory.groupClasses: 0.6,
      EquipmentCategory.functional: 0.6,
      EquipmentCategory.strength: 0.3,
    },
    UserGoal.stayFit: {
      EquipmentCategory.groupClasses: 1.0,
      EquipmentCategory.functional: 0.8,
      EquipmentCategory.cardio: 0.6,
      EquipmentCategory.strength: 0.5,
    },
    UserGoal.endurance: {
      EquipmentCategory.cardio: 1.0,
      EquipmentCategory.functional: 0.5,
      EquipmentCategory.groupClasses: 0.4,
      EquipmentCategory.strength: 0.1,
    },
  };

  /// Catégorie principale par objectif (pour l'explication locale).
  static const Map<UserGoal, EquipmentCategory> _mainCategory = {
    UserGoal.gainMuscle: EquipmentCategory.strength,
    UserGoal.loseWeight: EquipmentCategory.cardio,
    UserGoal.stayFit: EquipmentCategory.groupClasses,
    UserGoal.endurance: EquipmentCategory.cardio,
  };

  Future<RecommendationResult> recommend(RecommendationCriteria c) async {
    final gyms = await GymService.instance.getAll(status: GymStatus.open);

    final scored = <GymRecommendation>[];
    for (final g in gyms) {
      final equipments = await GymEquipmentService.instance.getByGym(g.id!);
      scored.add(_score(g, equipments, c));
    }

    int byScore(GymRecommendation a, GymRecommendation b) =>
        b.fitPercent.compareTo(a.fitPercent);

    // Les salles dans le budget passent avant celles qui le dépassent.
    final within = scored.where((r) => r.withinBudget).toList()..sort(byScore);
    final over = scored.where((r) => !r.withinBudget).toList()..sort(byScore);
    final top = [...within, ...over].take(3).toList();

    for (final r in top) {
      r.explanation = _localExplanation(r, c);
    }

    // L'IA reformule ; en cas d'échec on garde les textes locaux.
    final ai = await GymAiService.instance.explain(c, top);
    if (ai != null) {
      for (final r in top) {
        final text = ai.byGym[r.gym.id];
        if (text != null) r.explanation = text;
      }
    }

    return RecommendationResult(
      items: top,
      aiUsed: ai != null,
      summary: ai?.summary,
      noneWithinBudget: within.isEmpty && scored.isNotEmpty,
    );
  }

  // ---------- Score (sur 100) ----------

  GymRecommendation _score(
    Gym g,
    List<GymEquipment> equipments,
    RecommendationCriteria c,
  ) {
    // 1. Budget (30 points) : plus la salle est économique, mieux c'est.
    final withinBudget = g.priceMonthly <= c.maxBudget;
    final budgetScore =
        withinBudget ? 20 + 10 * (1 - g.priceMonthly / c.maxBudget) : 0.0;

    // 2. Localisation (30 points).
    double? distance;
    double locationScore;
    if (c.position != null && g.hasLocation) {
      distance = GeoUtils.distanceKm(
        c.position!.latitude,
        c.position!.longitude,
        g.latitude!,
        g.longitude!,
      );
      // 2 km ou moins : 30 points ; 30 km ou plus : 0.
      locationScore = 30 * (1 - (distance - 2) / 28).clamp(0.0, 1.0).toDouble();
    } else if (c.position != null) {
      locationScore = 8; // salle sans coordonnées : score neutre
    } else if (c.city != null) {
      locationScore =
          g.city.trim().toLowerCase() == c.city!.trim().toLowerCase() ? 30 : 0;
    } else {
      locationScore = 0;
    }

    // 3. Équipements utiles pour l'objectif (30 points).
    final usableByCategory = <EquipmentCategory, int>{};
    var usable = 0;
    var total = 0;
    for (final e in equipments) {
      total += e.quantity;
      if (e.isUsable) {
        usable += e.quantity;
        usableByCategory[e.category] =
            (usableByCategory[e.category] ?? 0) + e.quantity;
      }
    }
    final weights = _weights[c.goal]!;
    var fit = 0.0;
    var weightSum = 0.0;
    weights.forEach((category, weight) {
      weightSum += weight;
      // Au-delà de 5 appareils d'une catégorie, on considère qu'elle est bien fournie.
      fit += weight * min(usableByCategory[category] ?? 0, 5) / 5;
    });
    final goalScore = 30 * fit / weightSum;

    // 4. État du parc (10 points).
    final conditionScore = total == 0 ? 0.0 : 10 * usable / total;

    final percent =
        (budgetScore + locationScore + goalScore + conditionScore).round();

    return GymRecommendation(
      gym: g,
      fitPercent: max(0, min(100, percent)),
      distanceKm: distance,
      withinBudget: withinBudget,
      usableByCategory: usableByCategory,
      usableEquipment: usable,
      totalEquipment: total,
    );
  }

  /// Explication écrite en Dart (utilisée si l'IA est indisponible).
  String _localExplanation(GymRecommendation r, RecommendationCriteria c) {
    final parts = <String>[];

    if (r.distanceKm != null) {
      parts.add('À ${GeoUtils.format(r.distanceKm!)} de vous');
    } else if (c.city != null &&
        r.gym.city.trim().toLowerCase() == c.city!.trim().toLowerCase()) {
      parts.add('Dans votre ville (${r.gym.city})');
    }

    final price = r.gym.priceMonthly.toStringAsFixed(0);
    final budget = c.maxBudget.toStringAsFixed(0);
    parts.add(r.withinBudget
        ? '$price DT/mois, dans votre budget de $budget DT'
        : '$price DT/mois, au-dessus de votre budget de $budget DT');

    final main = _mainCategory[c.goal]!;
    final n = r.usableByCategory[main] ?? 0;
    parts.add(n > 0
        ? '$n équipement${n > 1 ? 's' : ''} '
            '${main.label.toLowerCase()} utilisable${n > 1 ? 's' : ''} '
            'pour votre objectif'
        : 'peu d\'équipements adaptés à votre objectif');

    return '${parts.join(' · ')}.';
  }
}
