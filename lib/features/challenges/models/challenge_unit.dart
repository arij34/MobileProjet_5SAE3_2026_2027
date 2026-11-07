/// Unité de mesure de l'objectif d'une tâche.
enum ChallengeUnit {
  reps('reps', 'Répétitions'),
  km('km', 'Kilomètres'),
  minutes('minutes', 'Minutes'),
  steps('steps', 'Pas'),
  kcal('kcal', 'Calories');

  final String value;
  final String label;

  const ChallengeUnit(this.value, this.label);

  static ChallengeUnit fromValue(String? value) {
    return ChallengeUnit.values.firstWhere(
      (unit) => unit.value == value,
      orElse: () => ChallengeUnit.reps,
    );
  }
}
