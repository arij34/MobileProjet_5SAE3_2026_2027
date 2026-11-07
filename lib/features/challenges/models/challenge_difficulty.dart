/// Difficulté d'un challenge, avec les points d'expérience proposés par défaut.
enum ChallengeDifficulty {
  easy('easy', 'Facile', 50),
  medium('medium', 'Moyen', 100),
  hard('hard', 'Difficile', 200);

  final String value; // valeur stockée dans la base
  final String label; // texte affiché à l'écran
  final int defaultXp; // XP proposés à la création

  const ChallengeDifficulty(this.value, this.label, this.defaultXp);

  static ChallengeDifficulty fromValue(String? value) {
    return ChallengeDifficulty.values.firstWhere(
      (difficulty) => difficulty.value == value,
      orElse: () => ChallengeDifficulty.medium,
    );
  }
}
