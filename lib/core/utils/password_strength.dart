import 'package:flutter/material.dart';

enum PasswordLevel {
  empty('', Colors.grey),
  weak('Faible', Color(0xFFD64545)),
  medium('Moyen', Color(0xFFE8920C)),
  good('Bon', Color(0xFFA86BEE)),
  strong('Fort', Color(0xFF2E9E6B));

  final String label;
  final Color color;
  const PasswordLevel(this.label, this.color);
}

class PasswordStrength {
  final int score; // 0 à 5
  final PasswordLevel level;
  final List<String> missing; // critères non remplis

  const PasswordStrength(this.score, this.level, this.missing);

  /// Progression entre 0.0 et 1.0 pour la barre.
  double get progress => score / 5;

  static PasswordStrength evaluate(String password) {
    if (password.isEmpty) {
      return const PasswordStrength(0, PasswordLevel.empty, []);
    }

    final missing = <String>[];
    var score = 0;

    if (password.length >= 8) {
      score++;
    } else {
      missing.add('8 caractères minimum');
    }
    if (RegExp(r'[a-z]').hasMatch(password)) {
      score++;
    } else {
      missing.add('une minuscule');
    }
    if (RegExp(r'[A-Z]').hasMatch(password)) {
      score++;
    } else {
      missing.add('une majuscule');
    }
    if (RegExp(r'[0-9]').hasMatch(password)) {
      score++;
    } else {
      missing.add('un chiffre');
    }
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      score++;
    } else {
      missing.add('un symbole (@, #, !...)');
    }

    final PasswordLevel level;
    if (score <= 2) {
      level = PasswordLevel.weak;
    } else if (score == 3) {
      level = PasswordLevel.medium;
    } else if (score == 4) {
      level = PasswordLevel.good;
    } else {
      level = PasswordLevel.strong;
    }

    return PasswordStrength(score, level, missing);
  }
}