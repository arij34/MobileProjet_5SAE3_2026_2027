import 'dart:math';

/// Gère les codes de vérification (mot de passe oublié).
/// Les codes sont gardés en mémoire : ils disparaissent quand l'application ferme.
class VerificationService {
  VerificationService._();
  static final VerificationService instance = VerificationService._();

  static const Duration validity = Duration(minutes: 10);
  static const int maxAttempts = 3;

  final Map<String, _PendingCode> _codes = {};

  /// Génère un code à 6 chiffres pour ce compte (clé = email) et le retourne.
  /// Un nouveau code remplace l'ancien.
  String generateCode(String email) {
    final code = (Random.secure().nextInt(900000) + 100000).toString();
    _codes[email] = _PendingCode(code, DateTime.now().add(validity));
    return code;
  }

  /// Vérifie le code saisi.
  /// Retourne null si le code est bon, sinon le message d'erreur à afficher.
  String? verify(String email, String input) {
    final pending = _codes[email];

    if (pending == null) {
      return 'Aucun code demandé. Renvoyez un code.';
    }
    if (DateTime.now().isAfter(pending.expiresAt)) {
      _codes.remove(email);
      return 'Le code a expiré. Renvoyez un code.';
    }
    if (pending.code != input.trim()) {
      pending.attempts++;
      if (pending.attempts >= maxAttempts) {
        _codes.remove(email);
        return 'Trop de tentatives. Renvoyez un code.';
      }
      final left = maxAttempts - pending.attempts;
      return 'Code incorrect ($left essai${left > 1 ? 's' : ''} restant${left > 1 ? 's' : ''}).';
    }

    _codes.remove(email); // code utilisé : on le supprime
    return null;
  }
}

class _PendingCode {
  final String code;
  final DateTime expiresAt;
  int attempts = 0;
  _PendingCode(this.code, this.expiresAt);
}