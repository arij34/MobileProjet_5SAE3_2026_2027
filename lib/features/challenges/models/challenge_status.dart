/// Statut enregistré d'un challenge : brouillon, actif ou annulé.
/// "À venir / en cours / terminé" n'est PAS stocké : voir [ChallengeTimeState].
enum ChallengeStatus {
  draft('draft', 'Brouillon'),
  pending('pending', 'En attente de validation'),
  rejected('rejected', 'Rejeté'),
  active('active', 'Approuvé'),
  cancelled('cancelled', 'Annulé');

  final String value;
  final String label;

  const ChallengeStatus(this.value, this.label);

  static ChallengeStatus fromValue(String? value) {
    return ChallengeStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ChallengeStatus.draft,
    );
  }
}

/// Position du challenge dans le temps, calculée à partir des dates
/// (jamais enregistrée dans la base).
enum ChallengeTimeState {
  upcoming('À venir'),
  ongoing('En cours'),
  ended('Terminé');

  final String label;

  const ChallengeTimeState(this.label);
}
