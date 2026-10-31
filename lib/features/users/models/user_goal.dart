/// Objectif sportif de l'utilisateur.
enum UserGoal {
  loseWeight('lose_weight', 'Perdre du poids'),
  gainMuscle('gain_muscle', 'Prendre du muscle'),
  stayFit('stay_fit', 'Rester en forme'),
  endurance('endurance', 'Améliorer l\'endurance');

  final String value; // valeur stockée dans la base
  final String label; // texte affiché à l'écran

  const UserGoal(this.value, this.label);

  static UserGoal? fromValue(String? value) {
    if (value == null) return null;
    for (final goal in UserGoal.values) {
      if (goal.value == value) return goal;
    }
    return null;
  }
}