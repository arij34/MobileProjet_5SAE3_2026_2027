import 'challenge_unit.dart';

/// Nature d'une tâche de challenge.
enum ChallengeType {
  workout('workout', 'Entraînement'),
  running('running', 'Course'),
  steps('steps', 'Pas'),
  nutrition('nutrition', 'Nutrition'),
  flexibility('flexibility', 'Souplesse'),
  custom('custom', 'Personnalisé');

  final String value;
  final String label;

  const ChallengeType(this.value, this.label);

  static ChallengeType fromValue(String? value) {
    return ChallengeType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ChallengeType.custom,
    );
  }

  /// Unité proposée par défaut quand on choisit ce type.
  ChallengeUnit get defaultUnit {
    switch (this) {
      case ChallengeType.running:
        return ChallengeUnit.km;
      case ChallengeType.steps:
        return ChallengeUnit.steps;
      case ChallengeType.nutrition:
        return ChallengeUnit.kcal;
      case ChallengeType.flexibility:
        return ChallengeUnit.minutes;
      case ChallengeType.workout:
      case ChallengeType.custom:
        return ChallengeUnit.reps;
    }
  }
}
