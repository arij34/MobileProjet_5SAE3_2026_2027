/// Niveau conseillé pour une activité sportive.
///
/// `value` est stockée en base, `label` est affichée à l'écran.
enum ActivityLevel {
  beginner('beginner', 'Débutant'),
  intermediate('intermediate', 'Intermédiaire'),
  advanced('advanced', 'Avancé');

  final String value;
  final String label;

  const ActivityLevel(this.value, this.label);

  static ActivityLevel fromValue(String? value) {
    return ActivityLevel.values.firstWhere(
      (l) => l.value == value,
      orElse: () => ActivityLevel.beginner,
    );
  }

  /// Mappe un libellé libre (proposition de l'IA) vers un niveau connu.
  static ActivityLevel fromLabelOrValue(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    for (final l in ActivityLevel.values) {
      if (l.value == v || l.label.toLowerCase() == v) return l;
    }
    // Quelques synonymes fréquents côté IA.
    if (v.startsWith('déb') || v.startsWith('deb')) return ActivityLevel.beginner;
    if (v.startsWith('inter')) return ActivityLevel.intermediate;
    if (v.startsWith('av')) return ActivityLevel.advanced;
    return ActivityLevel.beginner;
  }
}
