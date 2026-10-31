import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Carte niveau + barre de progression d'XP.
class XpCard extends StatelessWidget {
  final int level;
  final String title;
  final int totalXp;
  final int xpInLevel;
  final int xpForNext;
  final VoidCallback? onTap;

  const XpCard({
    super.key,
    required this.level,
    required this.title,
    required this.totalXp,
    required this.xpInLevel,
    required this.xpForNext,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = xpForNext == 0 ? 1.0 : xpInLevel / xpForNext;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.purpleLight,
              child: Text(
                '$level',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Niveau $level · $title',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '$totalXp XP',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.purpleLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor:
                          AppTheme.purpleLight.withValues(alpha: 0.15),
                      valueColor:
                          const AlwaysStoppedAnimation(AppTheme.purpleLight),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$xpInLevel / $xpForNext XP avant le niveau ${level + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}