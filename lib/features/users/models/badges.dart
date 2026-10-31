import 'package:flutter/material.dart';
import 'level_system.dart';
import 'profile_completion.dart';
import 'user.dart';

class AppBadge {
  final String label;
  final String description;
  final IconData icon;
  final bool earned;

  const AppBadge({
    required this.label,
    required this.description,
    required this.icon,
    required this.earned,
  });
}

/// Liste des badges. Ils sont calculés à partir de l'état de l'utilisateur :
/// rien à stocker dans la base.
class BadgeCatalog {
  BadgeCatalog._();

  /// [loginDays] = nombre de jours différents où l'utilisateur s'est connecté.
  static List<AppBadge> badgesFor(User user, int loginDays) {
    final level = LevelSystem.fromXp(user.xp).level;
    final complete = ProfileCompletion.of(user).percent >= 100;

    return [
      AppBadge(
        label: 'Bienvenue',
        description: 'Créer son compte MyGym',
        icon: Icons.waving_hand,
        earned: true,
      ),
      AppBadge(
        label: 'Photogénique',
        description: 'Choisir une photo de profil',
        icon: Icons.photo_camera,
        earned: user.photoUrl != null && user.photoUrl!.isNotEmpty,
      ),
      AppBadge(
        label: 'Sportif',
        description: 'Renseigner taille, poids et objectif',
        icon: Icons.fitness_center,
        earned:
            user.heightCm != null && user.weightKg != null && user.goal != null,
      ),
      AppBadge(
        label: 'Profil complet',
        description: 'Atteindre 100 % de profil complété',
        icon: Icons.verified,
        earned: complete,
      ),
      AppBadge(
        label: 'Fidèle',
        description: 'Se connecter 3 jours différents',
        icon: Icons.local_fire_department,
        earned: loginDays >= 3,
      ),
      AppBadge(
        label: 'Niveau 2',
        description: 'Atteindre le niveau 2',
        icon: Icons.military_tech,
        earned: level >= 2,
      ),
      AppBadge(
        label: 'Niveau 5',
        description: 'Atteindre le niveau 5',
        icon: Icons.emoji_events,
        earned: level >= 5,
      ),
    ];
  }
}