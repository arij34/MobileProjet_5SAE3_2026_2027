import '../../features/users/models/user.dart';
import '../../features/users/models/user_role.dart';
import 'session_manager.dart';

/// Toutes les actions qui peuvent être autorisées ou interdites selon le rôle.
///
/// Pour AJOUTER une action : l'ajouter ici, puis ajouter UNE ligne dans
/// `_rules` ci-dessous (une permission sans ligne n'est autorisée à personne).
enum Permission {
  // ----- Module Utilisateurs -----
  manageUsers, // ouvrir le tableau de bord administrateur
  validateAccounts, // valider / refuser les comptes en attente
  assignRoles, // changer le rôle d'un utilisateur

  // ----- Module Salles de sport -----
  viewGyms,
  manageGyms,

  // ----- Module Activités -----
  viewActivities,
  manageActivities,
  bookSession,

  // ----- Module Challenges -----
  viewChallenges,
  manageChallenges,
  joinChallenge,

  // ----- Module Nutrition -----
  viewNutrition,
  manageNutrition,

  // ----- Progression personnelle (XP, niveaux, badges) -----
  viewOwnProgress,
  editSportProfile, // taille, poids, objectif sportif
}

/// Qui a le droit de faire quoi.
///
/// POUR CHANGER UN DROIT : modifier la ligne de la permission dans `_rules`.
/// Rien d'autre à toucher : les écrans lisent cette table.
/// Chaque responsable de module gère les lignes de son module.
class Permissions {
  Permissions._();

  // Une ligne par permission = la liste des rôles autorisés.
  static const Map<Permission, Set<UserRole>> _rules = {
    // ===== MODULE UTILISATEURS (Arij) =====
    Permission.manageUsers: {UserRole.admin},
    Permission.validateAccounts: {UserRole.admin},
    Permission.assignRoles: {UserRole.admin},

    // ===== MODULE SALLES DE SPORT =====
    Permission.viewGyms: {
      UserRole.admin,
      UserRole.gymManager,
      UserRole.coach,
      UserRole.member,
    },
    Permission.manageGyms: {UserRole.admin, UserRole.gymManager},

    // ===== MODULE ACTIVITÉS =====
    Permission.viewActivities: {
      UserRole.admin,
      UserRole.gymManager,
      UserRole.coach,
      UserRole.member,
    },
    Permission.manageActivities: {UserRole.gymManager},
    Permission.bookSession: {UserRole.member},

    // ===== MODULE CHALLENGES =====
    Permission.viewChallenges: {
      UserRole.admin,
      UserRole.gymManager,
      UserRole.coach,
      UserRole.member,
    },
    Permission.manageChallenges: {UserRole.gymManager},
    Permission.joinChallenge: {UserRole.member},

    // ===== MODULE NUTRITION =====
    Permission.viewNutrition: {
      UserRole.admin,
      UserRole.nutritionist,
      UserRole.member,
    },
    Permission.manageNutrition: {UserRole.nutritionist},

    // ===== PROGRESSION PERSONNELLE =====
    // L'administrateur n'a ni XP, ni profil complété, ni profil sportif.
    Permission.viewOwnProgress: {
      UserRole.gymManager,
      UserRole.nutritionist,
      UserRole.coach,
      UserRole.member,
    },
    Permission.editSportProfile: {
      UserRole.gymManager,
      UserRole.nutritionist,
      UserRole.coach,
      UserRole.member,
    },
  };

  /// Les rôles autorisés pour cette permission.
  static Set<UserRole> rolesFor(Permission permission) =>
      _rules[permission] ?? const {};

  /// Ce rôle a-t-il cette permission ?
  static bool roleCan(UserRole role, Permission permission) =>
      rolesFor(permission).contains(role);

  /// Toutes les permissions d'un rôle.
  static Set<Permission> forRole(UserRole role) =>
      Permission.values.where((p) => roleCan(role, p)).toSet();

  /// Cet utilisateur a-t-il cette permission ?
  /// Un compte non actif (en attente ou désactivé) n'a aucune permission.
  static bool can(User user, Permission permission) =>
      user.isActive && roleCan(user.role, permission);

  /// Même chose pour l'utilisateur actuellement connecté.
  static bool currentCan(Permission permission) {
    final user = SessionManager.instance.currentUser;
    return user != null && can(user, permission);
  }
}