/// Statut d'un compte : actif, en attente de validation ou désactivé.
enum UserStatus {
  active('active', 'Actif'),
  pending('pending', 'En attente'),
  disabled('disabled', 'Désactivé');

  final String value;
  final String label;

  const UserStatus(this.value, this.label);

  static UserStatus fromValue(String? value) {
    return UserStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => UserStatus.active,
    );
  }
}