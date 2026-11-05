import 'nutrition_tables.dart';

/// Un aliment consommé dans un repas, avec sa quantité et ses valeurs
/// nutritionnelles déjà calculées (calories = quantité × valeur_100g / 100).
class MealItem {
  final int? id;
  final int? mealId;
  final int foodId;
  final double quantity; // grammes
  final double calories;
  final double proteins;
  final double carbs;
  final double fats;

  // Rempli par jointure (lecture seule).
  final String? foodName;

  const MealItem({
    this.id,
    this.mealId,
    required this.foodId,
    required this.quantity,
    required this.calories,
    required this.proteins,
    required this.carbs,
    required this.fats,
    this.foodName,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) MealItemTable.colId: id,
        MealItemTable.colMealId: mealId,
        MealItemTable.colFoodId: foodId,
        MealItemTable.colQuantity: quantity,
        MealItemTable.colCalories: calories,
        MealItemTable.colProteins: proteins,
        MealItemTable.colCarbs: carbs,
        MealItemTable.colFats: fats,
      };

  factory MealItem.fromMap(Map<String, dynamic> map) => MealItem(
        id: map[MealItemTable.colId] as int?,
        mealId: map[MealItemTable.colMealId] as int?,
        foodId: map[MealItemTable.colFoodId] as int,
        quantity: ((map[MealItemTable.colQuantity] as num?) ?? 0).toDouble(),
        calories: ((map[MealItemTable.colCalories] as num?) ?? 0).toDouble(),
        proteins: ((map[MealItemTable.colProteins] as num?) ?? 0).toDouble(),
        carbs: ((map[MealItemTable.colCarbs] as num?) ?? 0).toDouble(),
        fats: ((map[MealItemTable.colFats] as num?) ?? 0).toDouble(),
        foodName: map['food_name'] as String?,
      );

  MealItem copyWith({
    int? id,
    int? mealId,
    double? quantity,
    double? calories,
    double? proteins,
    double? carbs,
    double? fats,
  }) =>
      MealItem(
        id: id ?? this.id,
        mealId: mealId ?? this.mealId,
        foodId: foodId,
        quantity: quantity ?? this.quantity,
        calories: calories ?? this.calories,
        proteins: proteins ?? this.proteins,
        carbs: carbs ?? this.carbs,
        fats: fats ?? this.fats,
        foodName: foodName,
      );
}
