/// Les 4 rôles de l'application (cahier des charges, section 2.1).
enum UserRole {
  admin('admin', 'Administrateur'),
  gymManager('gym_manager', 'Responsable de salle'),
  nutritionist('nutritionist', 'Nutritionniste'),
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