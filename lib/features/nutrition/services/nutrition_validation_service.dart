/// Validateurs réutilisables pour les formulaires du module nutrition.
/// Chaque fonction renvoie `null` si la valeur est correcte, sinon un message
/// d'erreur en français (compatible avec les `validator` de Flutter).
class NutritionValidation {
  NutritionValidation._();

  /// Champ texte obligatoire (ex. nom d'un aliment).
  static String? requiredText(String? value, {String field = 'Ce champ'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field est obligatoire.';
    }
    return null;
  }

  /// Nom d'aliment : obligatoire, au moins 2 caractères.
  static String? foodName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Le nom est obligatoire.';
    if (v.length < 2) return 'Le nom est trop court.';
    return null;
  }

  /// Nombre positif ou nul (ex. calories, macros pour 100 g).
  static String? positiveOrZero(String? value, {String field = 'La valeur'}) {
    final v = (value ?? '').trim().replaceAll(',', '.');
    if (v.isEmpty) return '$field est obligatoire.';
    final n = double.tryParse(v);
    if (n == null) return 'Saisissez un nombre valide.';
    if (n < 0) return '$field ne peut pas être négative.';
    return null;
  }

  /// Quantité strictement positive (grammes).
  static String? quantity(String? value) {
    final v = (value ?? '').trim().replaceAll(',', '.');
    if (v.isEmpty) return 'La quantité est obligatoire.';
    final n = double.tryParse(v);
    if (n == null) return 'Saisissez un nombre valide.';
    if (n <= 0) return 'La quantité doit être supérieure à 0.';
    if (n > 5000) return 'Quantité irréaliste (max 5000 g).';
    return null;
  }

  /// Âge réaliste.
  static String? age(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'L\'âge est obligatoire.';
    final n = int.tryParse(v);
    if (n == null) return 'Saisissez un nombre entier.';
    if (n < 10 || n > 120) return 'Âge réaliste attendu (10 à 120).';
    return null;
  }

  /// Taille réaliste (cm).
  static String? height(String? value) {
    final v = (value ?? '').trim().replaceAll(',', '.');
    if (v.isEmpty) return 'La taille est obligatoire.';
    final n = double.tryParse(v);
    if (n == null) return 'Saisissez un nombre valide.';
    if (n < 100 || n > 250) return 'Taille réaliste attendue (100 à 250 cm).';
    return null;
  }

  /// Poids réaliste (kg).
  static String? weight(String? value) {
    final v = (value ?? '').trim().replaceAll(',', '.');
    if (v.isEmpty) return 'Le poids est obligatoire.';
    final n = double.tryParse(v);
    if (n == null) return 'Saisissez un nombre valide.';
    if (n < 25 || n > 350) return 'Poids réaliste attendu (25 à 350 kg).';
    return null;
  }

  /// Parse un nombre tolérant à la virgule décimale (null si invalide).
  static double? parseNumber(String? value) {
    if (value == null) return null;
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }
}
