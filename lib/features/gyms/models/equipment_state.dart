/// État d'un équipement : bon, à réparer ou hors service.
enum EquipmentState {
  good('good', 'Bon état'),
  needsRepair('needs_repair', 'À réparer'),
  outOfOrder('out_of_order', 'Hors service');

  final String value; // valeur stockée dans la base
  final String label; // texte affiché à l'écran

  const EquipmentState(this.value, this.label);

  static EquipmentState fromValue(String? value) {
    return EquipmentState.values.firstWhere(
      (state) => state.value == value,
      orElse: () => EquipmentState.good,
    );
  }
}
