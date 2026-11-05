/// Catégories d'activités sportives proposées dans une salle.
///
/// `value` est stockée en base, `label` est affichée à l'écran.
/// Toute valeur inconnue retombe sur [ActivityCategory.other] (jamais d'erreur).
enum ActivityCategory {
  cardio('cardio', 'Cardio'),
  strength('strength', 'Musculation'),
  yoga('yoga', 'Yoga'),
  pilates('pilates', 'Pilates'),
  dance('dance', 'Danse'),
  combat('combat', 'Sports de combat'),
  aquatic('aquatic', 'Aquatique'),
  crossfit('crossfit', 'CrossFit'),
  cycling('cycling', 'Cyclisme / RPM'),
  stretching('stretching', 'Étirements / Mobilité'),
  collective('collective', 'Cours collectif'),
  other('other', 'Autre');

  final String value;
  final String label;

  const ActivityCategory(this.value, this.label);

  static ActivityCategory fromValue(String? value) {
    return ActivityCategory.values.firstWhere(
      (c) => c.value == value,
      orElse: () => ActivityCategory.other,
    );
  }

  /// Retrouve une catégorie à partir d'un libellé libre (utilisé pour mapper
  /// une proposition de l'IA). Compare la valeur ET le libellé, sans casse.
  static ActivityCategory fromLabelOrValue(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    if (v.isEmpty) return ActivityCategory.other;
    for (final c in ActivityCategory.values) {
      if (c.value == v || c.label.toLowerCase() == v) return c;
    }
    return ActivityCategory.other;
  }
}
