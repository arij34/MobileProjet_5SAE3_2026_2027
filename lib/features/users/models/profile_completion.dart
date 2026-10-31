import 'user.dart';

/// Calcule le pourcentage de profil complété d'un utilisateur.
/// Chaque élément a le même poids ; la liste `missing` dit ce qu'il reste à remplir.
class ProfileCompletion {
  final int percent; // de 0 à 100
  final List<String> missing;

  const ProfileCompletion(this.percent, this.missing);

  static ProfileCompletion of(User user) {
    final checks = <String, bool>{
      'Prénom': user.firstName.trim().isNotEmpty,
      'Nom': user.lastName.trim().isNotEmpty,
      'Email': user.email.trim().isNotEmpty,
      'Téléphone': user.phone.trim().isNotEmpty,
      'Photo de profil': user.photoUrl != null && user.photoUrl!.isNotEmpty,
      'Date de naissance': user.birthDate != null,
      'Taille': user.heightCm != null,
      'Poids': user.weightKg != null,
      'Objectif sportif': user.goal != null,
    };

    final done = checks.values.where((ok) => ok).length;
    final missing =
        checks.entries.where((e) => !e.value).map((e) => e.key).toList();

    return ProfileCompletion((done * 100 / checks.length).round(), missing);
  }
}