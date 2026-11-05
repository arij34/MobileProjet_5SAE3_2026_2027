import 'gym_membership_table.dart';
import 'membership_status.dart';

/// Une demande ou une adhésion d'un adhérent à une salle.
class GymMembership {
  final int? id;
  final int userId;
  final int gymId;
  final int months;
  final double priceTotal;
  final MembershipStatus status;
  final String? qrToken;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  // Remplis par les requêtes avec jointure (lecture seule, jamais stockés ici).
  final String? gymName;
  final String? gymCity;
  final String? memberName;

  const GymMembership({
    this.id,
    required this.userId,
    required this.gymId,
    required this.months,
    required this.priceTotal,
    this.status = MembershipStatus.pending,
    this.qrToken,
    this.startDate,
    this.endDate,
    required this.createdAt,
    this.gymName,
    this.gymCity,
    this.memberName,
  });

  /// Active ET non expirée (la date est revérifiée ici, au cas où la base
  /// n'a pas encore été mise à jour).
  bool get isActive =>
      status == MembershipStatus.active &&
      (endDate == null || endDate!.isAfter(DateTime.now()));

  String get formulaLabel => months == 1 ? '1 mois' : '$months mois';

  /// Code lisible par groupes de 4 (ex. ABCD-EFGH-...), pour la saisie manuelle.
  String get codeLabel {
    final t = qrToken ?? '';
    final parts = <String>[];
    for (var i = 0; i < t.length; i += 4) {
      parts.add(t.substring(i, i + 4 > t.length ? t.length : i + 4));
    }
    return parts.join('-');
  }

  static String formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) GymMembershipTable.colId: id,
      GymMembershipTable.colUserId: userId,
      GymMembershipTable.colGymId: gymId,
      GymMembershipTable.colMonths: months,
      GymMembershipTable.colPriceTotal: priceTotal,
      GymMembershipTable.colStatus: status.value,
      GymMembershipTable.colQrToken: qrToken,
      GymMembershipTable.colStartDate: startDate?.toIso8601String(),
      GymMembershipTable.colEndDate: endDate?.toIso8601String(),
      GymMembershipTable.colCreatedAt: createdAt.toIso8601String(),
    };
  }

  factory GymMembership.fromMap(Map<String, dynamic> map) {
    final start = map[GymMembershipTable.colStartDate] as String?;
    final end = map[GymMembershipTable.colEndDate] as String?;
    return GymMembership(
      id: map[GymMembershipTable.colId] as int?,
      userId: map[GymMembershipTable.colUserId] as int,
      gymId: map[GymMembershipTable.colGymId] as int,
      months: map[GymMembershipTable.colMonths] as int,
      priceTotal:
          ((map[GymMembershipTable.colPriceTotal] as num?) ?? 0).toDouble(),
      status: MembershipStatus.fromValue(
          map[GymMembershipTable.colStatus] as String?),
      qrToken: map[GymMembershipTable.colQrToken] as String?,
      startDate: start == null ? null : DateTime.tryParse(start),
      endDate: end == null ? null : DateTime.tryParse(end),
      createdAt:
          DateTime.parse(map[GymMembershipTable.colCreatedAt] as String),
      gymName: map['gym_name'] as String?,
      gymCity: map['gym_city'] as String?,
      memberName: map['member_name'] as String?,
    );
  }
}
