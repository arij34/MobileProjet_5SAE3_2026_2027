import 'package:flutter/material.dart';

enum NotificationType {
  challengePosted('challenge_posted', 'Nouveau challenge', Icons.emoji_events),
  challengePendingReview(
    'challenge_pending_review',
    'À valider',
    Icons.pending_actions,
  ),
  challengeApproved(
    'challenge_approved',
    'Challenge approuvé',
    Icons.check_circle_outline,
  ),
  challengeRejected(
    'challenge_rejected',
    'Challenge rejeté',
    Icons.error_outline,
  );

  final String value;
  final String label;
  final IconData icon;

  const NotificationType(this.value, this.label, this.icon);

  static NotificationType fromValue(String value) => values.firstWhere(
    (type) => type.value == value,
    orElse: () =>
        throw FormatException('Type de notification inconnu : $value'),
  );
}
