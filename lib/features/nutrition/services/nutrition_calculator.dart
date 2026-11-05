import '../../users/models/user_gender.dart';
import '../models/food.dart';
import '../models/meal_item.dart';
import '../models/nutrition_enums.dart';

/// Objectifs nutritionnels calculés (valeurs journalières recommandées).
class NutritionTargets {
  final double calories;
  final double proteins; // grammes
  final double carbs; // grammes
  final double fats; // grammes
  final double bmr; // métabolisme de base (kcal)
  final double tdee; // dépense énergétique journalière (kcal)

  const NutritionTargets({
    required this.calories,
    required this.proteins,
    required this.carbs,
    required this.fats,
    required this.bmr,
    required this.tdee,
  });
}

/// Calculs nutritionnels : mise à l'échelle des aliments, IMC, BMR, TDEE,
/// objectif calorique et répartition des macronutriments.
///
/// Les formules utilisées sont reconnues (Mifflin-St Jeor pour le BMR, facteurs
/// d'activité standards pour le TDEE). Les résultats sont des ESTIMATIONS et ne
/// remplacent pas l'avis d'un professionnel de santé.
class NutritionCalculator {
  NutritionCalculator._();

  /// Rapporte les kcal/g et macros d'un aliment à une quantité en grammes.
  /// Exemple : 150 g d'un aliment à 165 kcal/100 g => 247,5 kcal.
  static MealItem scale(Food food, double grams) {
    final f = grams / 100.0;
    return MealItem(
      foodId: food.id!,
      quantity: grams,
      calories: _round1(food.caloriesPer100g * f),
      proteins: _round1(food.proteinPer100g * f),
      carbs: _round1(food.carbsPer100g * f),
      fats: _round1(food.fatsPer100g * f),
      foodName: food.name,
    );
  }

  /// IMC = poids(kg) / taille(m)².
  static double bmi(double weightKg, double heightCm) {
    final m = heightCm / 100.0;
    return weightKg / (m * m);
  }

  /// Catégorie d'IMC (OMS).
  static String bmiCategory(double value) {
    if (value < 18.5) return 'Insuffisance pondérale';
    if (value < 25) return 'Corpulence normale';
    if (value < 30) return 'Surpoids';
    return 'Obésité';
  }

  /// Métabolisme de base (BMR) — formule de Mifflin-St Jeor.
  ///   Homme : 10·poids + 6,25·taille − 5·âge + 5
  ///   Femme : 10·poids + 6,25·taille − 5·âge − 161
  static double bmr({
    required double weightKg,
    required double heightCm,
    required int age,
    required UserGender sex,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    return sex == UserGender.male ? base + 5 : base - 161;
  }

  /// Dépense énergétique journalière = BMR × facteur d'activité.
  static double tdee(double bmrValue, NutritionActivityLevel level) =>
      bmrValue * level.factor;

  /// Objectifs complets selon le profil. Répartition des macros par objectif
  /// (en % des calories ; protéines/glucides = 4 kcal/g, lipides = 9 kcal/g).
  static NutritionTargets targets({
    required double weightKg,
    required double heightCm,
    required int age,
    required UserGender sex,
    required NutritionActivityLevel activity,
    required NutritionGoal goal,
  }) {
    final b = bmr(weightKg: weightKg, heightCm: heightCm, age: age, sex: sex);
    final t = tdee(b, activity);
    final calories = t * (1 + goal.calorieAdjustment);

    // Pourcentages de répartition selon l'objectif.
    final double pProt, pCarb, pFat;
    switch (goal) {
      case NutritionGoal.gainMass:
        pProt = 0.30;
        pCarb = 0.45;
        pFat = 0.25;
        break;
      case NutritionGoal.loseWeight:
        pProt = 0.35;
        pCarb = 0.35;
        pFat = 0.30;
        break;
      case NutritionGoal.maintain:
        pProt = 0.25;
        pCarb = 0.50;
        pFat = 0.25;
        break;
    }

    return NutritionTargets(
      calories: _round0(calories),
      proteins: _round0(calories * pProt / 4),
      carbs: _round0(calories * pCarb / 4),
      fats: _round0(calories * pFat / 9),
      bmr: _round0(b),
      tdee: _round0(t),
    );
  }

  static double _round1(double v) => (v * 10).round() / 10;
  static double _round0(double v) => v.roundToDouble();
}
