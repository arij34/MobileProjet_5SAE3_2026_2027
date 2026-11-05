/// Statut d'une réservation de séance.
///
/// - [confirmed]   : place obtenue.
/// - [waitlisted]  : séance complète, l'adhérent est en liste d'attente.
/// - [cancelled]   : réservation annulée (par l'adhérent ou devenue caduque).
enum ReservationStatus {
  confirmed('confirmed', 'Confirmée'),
  waitlisted('waitlisted', 'Liste d\'attente'),
  cancelled('cancelled', 'Annulée');

  final String value; // valeur stockée dans la base
  final String label; // texte affiché à l'écran

  const ReservationStatus(this.value, this.label);

  /// Statuts considérés comme « actifs » (occupent une place ou une position).
  static const List<ReservationStatus> active = [confirmed, waitlisted];

  static ReservationStatus fromValue(String? value) {
    return ReservationStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => ReservationStatus.cancelled,
    );
  }
}
