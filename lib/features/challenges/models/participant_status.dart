enum ParticipantStatus {
  joined('joined', 'En cours'),
  completed('completed', 'Terminé'),
  abandoned('abandoned', 'Abandonné');

  const ParticipantStatus(this.value, this.label);
  final String value;
  final String label;

  static ParticipantStatus fromValue(String value) =>
      ParticipantStatus.values.firstWhere((status) => status.value == value);
}
