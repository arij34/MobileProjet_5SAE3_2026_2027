import 'package:flutter_test/flutter_test.dart';
import 'package:mygym/features/nutrition/models/food.dart';
import 'package:mygym/features/nutrition/models/nutrition_enums.dart';
import 'package:mygym/features/nutrition/services/nutrition_calculator.dart';
import 'package:mygym/features/users/models/user_gender.dart';

void main() {
  final food = Food(
    id: 1,
    name: 'Poulet',
    caloriesPer100g: 165,
    proteinPer100g: 31,
    carbsPer100g: 0,
    fatsPer100g: 3.6,
    createdAt: DateTime(2024),
  );

  group('scale (calcul par quantité)', () {
    test('150 g de poulet = 247,5 kcal', () {
      final item = NutritionCalculator.scale(food, 150);
      expect(item.calories, 247.5);
      expect(item.proteins, 46.5);
      expect(item.fats, 5.4);
      expect(item.quantity, 150);
    });

    test('100 g = valeurs pour 100 g', () {
      final item = NutritionCalculator.scale(food, 100);
      expect(item.calories, 165);
      expect(item.proteins, 31);
    });
  });

  group('IMC', () {
    test('80 kg / 180 cm ≈ 24,7', () {
      expect(NutritionCalculator.bmi(80, 180).toStringAsFixed(1), '24.7');
    });
    test('catégories', () {
      expect(NutritionCalculator.bmiCategory(17), 'Insuffisance pondérale');
      expect(NutritionCalculator.bmiCategory(22), 'Corpulence normale');
      expect(NutritionCalculator.bmiCategory(27), 'Surpoids');
      expect(NutritionCalculator.bmiCategory(32), 'Obésité');
    });
  });

  group('BMR (Mifflin-St Jeor)', () {
    test('homme 80 kg / 180 cm / 30 ans = 1780', () {
      final b = NutritionCalculator.bmr(
          weightKg: 80, heightCm: 180, age: 30, sex: UserGender.male);
      expect(b, 1780);
    });
    test('femme 80 kg / 180 cm / 30 ans = 1614', () {
      final b = NutritionCalculator.bmr(
          weightKg: 80, heightCm: 180, age: 30, sex: UserGender.female);
      expect(b, 1614);
    });
  });

  group('TDEE et objectifs', () {
    test('TDEE = BMR × facteur d\'activité', () {
      final t = NutritionCalculator.tdee(1780, NutritionActivityLevel.moderate);
      expect(t.round(), 2759); // 1780 * 1.55
    });

    test('objectif maintien = TDEE, macros cohérentes', () {
      final t = NutritionCalculator.targets(
        weightKg: 80,
        heightCm: 180,
        age: 30,
        sex: UserGender.male,
        activity: NutritionActivityLevel.moderate,
        goal: NutritionGoal.maintain,
      );
      expect(t.calories, t.tdee); // ajustement 0 %
      // Somme des macros (en kcal) ≈ calories.
      final kcal = t.proteins * 4 + t.carbs * 4 + t.fats * 9;
      expect((kcal - t.calories).abs() < 30, true);
    });

    test('prise de masse ajoute des calories, perte en retire', () {
      NutritionTargets make(NutritionGoal g) => NutritionCalculator.targets(
            weightKg: 80,
            heightCm: 180,
            age: 30,
            sex: UserGender.male,
            activity: NutritionActivityLevel.moderate,
            goal: g,
          );
      final gain = make(NutritionGoal.gainMass);
      final lose = make(NutritionGoal.loseWeight);
      final maintain = make(NutritionGoal.maintain);
      expect(gain.calories > maintain.calories, true);
      expect(lose.calories < maintain.calories, true);
    });
  });
}
