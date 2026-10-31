/// Niveau calculé à partir de l'XP total.
class LevelInfo {
  final int level;
  final String title;
  final int xpInLevel; // XP gagnés dans le niveau actuel
  final int xpForNext; // XP nécessaires pour passer au niveau suivant

  const LevelInfo({
    required this.level,
    required this.title,
    required this.xpInLevel,
    required this.xpForNext,
  });

  double get progress => xpForNext == 0 ? 1 : xpInLevel / xpForNext;
}

class LevelSystem {
  LevelSystem._();

  /// Chaque niveau demande 100 XP.
  static const int xpPerLevel = 100;

  static LevelInfo fromXp(int xp) {
    final safe = xp < 0 ? 0 : xp;
    final level = safe ~/ xpPerLevel + 1;
    return LevelInfo(
      level: level,
      title: _titleFor(level),
      xpInLevel: safe % xpPerLevel,
      xpForNext: xpPerLevel,
    );
  }

  static String _titleFor(int level) {
    if (level < 3) return 'Débutant';
    if (level < 5) return 'Motivé';
    if (level < 8) return 'Athlète';
    return 'Champion';
  }
}