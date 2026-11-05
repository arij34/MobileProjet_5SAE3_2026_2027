/// Catégorie d'un équipement de salle.
enum EquipmentCategory {
  cardio('cardio', 'Cardio'),
  strength('strength', 'Musculation'),
  groupClasses('group_classes', 'Cours collectifs'),
  functional('functional', 'Fonctionnel'),
  other('other', 'Autre');

  final String value; // valeur stockée dans la base
  final String label; // texte affiché à l'écran

  const EquipmentCategory(this.value, this.label);

  static EquipmentCategory fromValue(String? value) {
    return EquipmentCategory.values.firstWhere(
      (category) => category.value == value,
      orElse: () => EquipmentCategory.other,
    );
  }
}
