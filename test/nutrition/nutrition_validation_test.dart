import 'package:flutter_test/flutter_test.dart';
import 'package:mygym/features/nutrition/services/nutrition_validation_service.dart';

void main() {
  group('Validation des quantités', () {
    test('refuse vide, zéro, négatif et non numérique', () {
      expect(NutritionValidation.quantity(''), isNotNull);
      expect(NutritionValidation.quantity('0'), isNotNull);
      expect(NutritionValidation.quantity('-5'), isNotNull);
      expect(NutritionValidation.quantity('abc'), isNotNull);
      expect(NutritionValidation.quantity('99999'), isNotNull); // irréaliste
    });
    test('accepte une quantité valide (virgule tolérée)', () {
      expect(NutritionValidation.quantity('150'), isNull);
      expect(NutritionValidation.quantity('12,5'), isNull);
    });
  });

  group('Validation du profil', () {
    test('âge', () {
      expect(NutritionValidation.age('5'), isNotNull);
      expect(NutritionValidation.age('200'), isNotNull);
      expect(NutritionValidation.age('30'), isNull);
      expect(NutritionValidation.age('trente'), isNotNull);
    });
    test('taille', () {
      expect(NutritionValidation.height('50'), isNotNull);
      expect(NutritionValidation.height('180'), isNull);
    });
    test('poids', () {
      expect(NutritionValidation.weight('10'), isNotNull);
      expect(NutritionValidation.weight('80'), isNull);
    });
  });

  group('Validation des aliments', () {
    test('nom obligatoire et assez long', () {
      expect(NutritionValidation.foodName(''), isNotNull);
      expect(NutritionValidation.foodName('a'), isNotNull);
      expect(NutritionValidation.foodName('Riz'), isNull);
    });
    test('macros : refuse négatif, accepte 0', () {
      expect(NutritionValidation.positiveOrZero('-1'), isNotNull);
      expect(NutritionValidation.positiveOrZero('0'), isNull);
      expect(NutritionValidation.positiveOrZero('165'), isNull);
    });
  });
}
