import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Hachage des mots de passe : SHA-256 avec un sel aléatoire.
/// Format stocké en base : `sel:hash`. Le mot de passe n'est jamais stocké en clair.
class PasswordHasher {
  static String hash(String password) {
    final salt = _generateSalt();
    return '$salt:${_digest(password, salt)}';
  }

  static bool verify(String password, String stored) {
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    return _digest(password, parts[0]) == parts[1];
  }

  static String _digest(String password, String salt) {
    return sha256.convert(utf8.encode('$salt$password')).toString();
  }

  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}