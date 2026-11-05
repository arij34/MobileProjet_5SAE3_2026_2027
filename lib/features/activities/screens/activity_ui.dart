import 'package:flutter/material.dart';

import '../models/activity_session.dart';
import '../models/reservation_status.dart';

/// Palette et petits widgets partagés par les écrans du module Activités.
/// (Reprend les couleurs MyGym utilisées dans les autres modules.)
class AColors {
  AColors._();
  static const violetDark = Color(0xFF4C378E);
  static const violet = Color(0xFFA86BEE);
  static const pink = Color(0xFFD43DA7);
  static const grayLight = Color(0xFFEFEDF5);
  static const lilac = Color(0xFFE8D8FC);
  static const textSecondary = Color(0xFF7A7390);
  static const orange = Color(0xFFE8920C);
  static const green = Color(0xFF2E9E6B);
  static const red = Color(0xFFD1495B);
}

/// SnackBar cohérente (verte = succès, rouge = erreur, violette sinon).
void showASnack(BuildContext context, String message, {Color? color}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color ?? AColors.violetDark,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
}

/// Petite étiquette colorée (icône + texte).
Widget pill(IconData icon, String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );

/// Étiquette « places restantes » : verte si libre, orange si bientôt plein,
/// rouge si complet (met en avant le nombre de places restantes).
Widget placesChip(ActivitySession s) {
  if (s.isFull) {
    return pill(Icons.event_busy, 'Complet · ${s.waitlistCount} en attente',
        AColors.red);
  }
  final color = s.remaining <= 2 ? AColors.orange : AColors.green;
  final word = s.remaining == 1 ? 'place' : 'places';
  return pill(Icons.event_seat, '${s.remaining} $word / ${s.capacityMax}', color);
}

/// Étiquette de statut d'une réservation.
Widget reservationStatusChip(ReservationStatus status) {
  switch (status) {
    case ReservationStatus.confirmed:
      return pill(Icons.check_circle, status.label, AColors.green);
    case ReservationStatus.waitlisted:
      return pill(Icons.hourglass_bottom, status.label, AColors.orange);
    case ReservationStatus.cancelled:
      return pill(Icons.cancel, status.label, AColors.textSecondary);
  }
}
