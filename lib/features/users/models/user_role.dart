/// Les rôles de l'application (cahier des charges, section 2.1).
enum UserRole {
  admin('admin', 'Administrateur'),
  gymManager('gym_manager', 'Responsable de salle'),
  nutritionist('nutritionist', 'Nutritionniste'),
  coach('coach', 'Coach'),
  member('member', 'Adhérent');

  final String value; // valeur stockée dans la base
  final String label; // texte affiché à l'écran

  const UserRole(this.value, this.label);

  static UserRole fromValue(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.member,
    );
  }
}

/// Type de coach : rattaché à une salle ou indépendant.
enum CoachType {
  gymCoach('gym_coach', 'Coach dans une salle'),
  freeCoach('free_coach', 'Coach libre (sans salle)');

  final String value;
  final String label;

  const CoachType(this.value, this.label);

  static CoachType? fromValue(String? value) {
    if (value == null) return null;
    for (final type in CoachType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}