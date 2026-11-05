/// Statut d'une salle : ouverte, fermée ou en attente d'ouverture.
enum GymStatus {
  open('open', 'Ouverte'),
  closed('closed', 'Fermée'),
  pending('pending', 'En attente');

  final String value; // valeur stockée dans la base
  final String label; // texte affiché à l'écran

  const GymStatus(this.value, this.label);

  static GymStatus fromValue(String? value) {
    return GymStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => GymStatus.open,
    );
  }
}
