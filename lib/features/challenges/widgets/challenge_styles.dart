import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/challenge_status.dart';

BoxDecoration challengeCardDecoration() => BoxDecoration(
  color: AppTheme.surface,
  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
  boxShadow: AppTheme.cardShadow,
);

class ChallengeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const ChallengeChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppTheme.pillRadius),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class ChallengeStateChip extends StatelessWidget {
  final ChallengeTimeState state;
  final String label;
  const ChallengeStateChip({
    super.key,
    required this.state,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (state) {
      ChallengeTimeState.upcoming => (AppTheme.purpleLight, Icons.schedule),
      ChallengeTimeState.ongoing => (
        AppTheme.success,
        Icons.play_circle_outline,
      ),
      ChallengeTimeState.ended => (
        AppTheme.textSecondary,
        Icons.check_circle_outline,
      ),
    };
    return ChallengeChip(label: label, icon: icon, color: color);
  }
}

class ChallengeStatusChip extends StatelessWidget {
  final ChallengeStatus status;
  const ChallengeStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      ChallengeStatus.draft => (AppTheme.textSecondary, Icons.edit_outlined),
      ChallengeStatus.pending => (AppTheme.purpleLight, Icons.schedule),
      ChallengeStatus.active => (AppTheme.success, Icons.check_circle_outline),
      ChallengeStatus.rejected => (AppTheme.error, Icons.info_outline),
      ChallengeStatus.cancelled => (
        AppTheme.textSecondary,
        Icons.cancel_outlined,
      ),
    };
    return ChallengeChip(label: status.label, icon: icon, color: color);
  }
}

class ChallengeIconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  const ChallengeIconTile({
    super.key,
    this.icon = Icons.emoji_events,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: AppTheme.challengeGradient,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Icon(icon, color: AppTheme.surface, size: size * 0.54),
  );
}
