import 'package:flutter/material.dart';

import '../models/membership_status.dart';

/// Couleur associée à un statut (vert, orange, rouge, gris : états seulement).
Color membershipStatusColor(MembershipStatus s) {
  switch (s) {
    case MembershipStatus.active:
      return const Color(0xFF2E9E6B);
    case MembershipStatus.pending:
      return const Color(0xFFE8920C);
    case MembershipStatus.rejected:
      return const Color(0xFFD64545);
    case MembershipStatus.expired:
    case MembershipStatus.cancelled:
      return const Color(0xFF7A7390);
  }
}

/// Pastille de statut d'une adhésion.
class MembershipStatusChip extends StatelessWidget {
  final MembershipStatus status;
  const MembershipStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = membershipStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
