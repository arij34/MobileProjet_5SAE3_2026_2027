/// Statut d'un coach dans une salle.
enum GymCoachStatus {
  active('active', 'Actif'),
  suspended('suspended', 'Suspendu');

  final String value; // valeur stockée dans la base
  final String label; // texte affiché à l'écran
  const GymCoachStatus(this.value, this.label);

  static GymCoachStatus fromValue(String? value) =>
      GymCoachStatus.values.firstWhere(
        (s) => s.value == value,
        orElse: () => GymCoachStatus.active,
      );
}

/// Statut d'une demande salle <-> coach.
enum CoachRequestStatus {
  pending('pending', 'En attente'),
  accepted('accepted', 'Acceptée'),
  rejected('rejected', 'Refusée'),
  cancelled('cancelled', 'Annulée');

  final String value;
  final String label;
  const CoachRequestStatus(this.value, this.label);

  static CoachRequestStatus fromValue(String? value) =>
      CoachRequestStatus.values.firstWhere(
        (s) => s.value == value,
        orElse: () => CoachRequestStatus.pending,
      );
}

/// Qui a envoyé la demande : la salle (invitation) ou le coach (candidature).
enum CoachRequestInitiator {
  gym('gym', 'La salle'),
  coach('coach', 'Le coach');

  final String value;
  final String label;
  const CoachRequestInitiator(this.value, this.label);

  static CoachRequestInitiator fromValue(String? value) =>
      CoachRequestInitiator.values.firstWhere(
        (s) => s.value == value,
        orElse: () => CoachRequestInitiator.gym,
      );
}
