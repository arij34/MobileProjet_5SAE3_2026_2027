/// Statut d'une adhésion à une salle.
enum MembershipStatus {
  pending('pending', 'En attente'),
  active('active', 'Active'),
  rejected('rejected', 'Refusée'),
  expired('expired', 'Expirée'),
  cancelled('cancelled', 'Annulée');

  final String value; // valeur stockée dans la base
  final String label; // texte affiché à l'écran

  const MembershipStatus(this.value, this.label);

  static MembershipStatus fromValue(String? value) {
    return MembershipStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => MembershipStatus.pending,
    );
  }
}
