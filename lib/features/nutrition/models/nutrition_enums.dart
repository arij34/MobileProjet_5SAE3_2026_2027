import 'package:flutter/material.dart';

import '../../users/models/user_goal.dart';

/// Les quatre moments de repas de la journée.
enum MealType {
  breakfast('breakfast', 'Petit-déjeuner', Icons.free_breakfast),
  lunch('lunch', 'Déjeuner', Icons.lunch_dining),
  snack('snack', 'Collation', Icons.cookie),
  dinner('dinner', 'Dîner', Icons.dinner_dining);

  final String value;
  final String label;
  final IconData icon;

  const MealType(this.value, this.label, this.icon);

  static MealType fromValue(String? value) => MealType.values.firstWhere(
        (m) => m.value == value,
        orElse: () => MealType.breakfast,
      );
}

/// Catégories d'aliments (pour le filtre et le classement).
enum FoodCategory {
  protein('protein', 'Protéines'),
  grain('grain', 'Féculents'),
  vegetable('vegetable', 'Légumes'),
  fruit('fruit', 'Fruits'),
  dairy('dairy', 'Produits laitiers'),
  fat('fat', 'Matières grasses'),
  drink('drink', 'Boissons'),
  other('other', 'Autre');

  final String value;
  final String label;

  const FoodCategory(this.value, this.label);

  static FoodCategory fromValue(String? value) => FoodCategory.values.firstWhere(
        (c) => c.value == value,
        orElse: () => FoodCategory.other,
      );

  static FoodCategory fromLabelOrValue(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    for (final c in FoodCategory.values) {
      if (c.value == v || c.label.toLowerCase() == v) return c;
    }
    return FoodCategory.other;
  }
}

/// Niveau d'activité physique + facteur multiplicateur du TDEE
/// (facteurs standards appliqués au métabolisme de base - BMR).
enum NutritionActivityLevel {
  sedentary('sedentary', 'Sédentaire', 1.2),
  light('light', 'Légèrement actif', 1.375),
  moderate('moderate', 'Modérément actif', 1.55),
  active('active', 'Très actif', 1.725),
  veryActive('very_active', 'Extrêmement actif', 1.9);

  final String value;
  final String label;
  final double factor;

  const NutritionActivityLevel(this.value, this.label, this.factor);

  static NutritionActivityLevel fromValue(String? value) =>
      NutritionActivityLevel.values.firstWhere(
        (a) => a.value == value,
        orElse: () => NutritionActivityLevel.moderate,
      );
}

/// Objectif nutritionnel + ajustement calorique appliqué au TDEE.
enum NutritionGoal {
  gainMass('gain_mass', 'Prise de masse', 0.15), // +15 %
  loseWeight('lose_weight', 'Perte de poids', -0.20), // -20 %
  maintain('maintain', 'Maintien du poids', 0.0);

  final String value;
  final String label;
  final double calorieAdjustment;

  const NutritionGoal(this.value, this.label, this.calorieAdjustment);

  static NutritionGoal fromValue(String? value) => NutritionGoal.values
      .firstWhere((g) => g.value == value, orElse: () => NutritionGoal.maintain);

  /// Valeur par défaut déduite de l'objectif sportif du module Utilisateurs.
  static NutritionGoal fromUserGoal(UserGoal? goal) {
    switch (goal) {
      case UserGoal.loseWeight:
        return NutritionGoal.loseWeight;
      case UserGoal.gainMuscle:
        return NutritionGoal.gainMass;
      default:
        return NutritionGoal.maintain;
    }
  }
}
