/// Sexe de l'utilisateur.
enum UserGender {
  male('male', 'Homme'),
  female('female', 'Femme');

  final String value; // valeur stockée dans la base
  final String label; // texte affiché à l'écran

  const UserGender(this.value, this.label);

  static UserGender? fromValue(String? value) {
    if (value == null) return null;
    for (final g in UserGender.values) {
      if (g.value == value) return g;
    }
    return null;
  }
}