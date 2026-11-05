import 'nutrition_enums.dart';
import 'nutrition_tables.dart';

/// Un aliment du catalogue (valeurs nutritionnelles pour 100 g).
class Food {
  final int? id;
  final String name;
  final FoodCategory category;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatsPer100g;
  final bool isCustom;
  final DateTime createdAt;

  const Food({
    this.id,
    required this.name,
    this.category = FoodCategory.other,
    this.caloriesPer100g = 0,
    this.proteinPer100g = 0,
    this.carbsPer100g = 0,
    this.fatsPer100g = 0,
    this.isCustom = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) FoodTable.colId: id,
        FoodTable.colName: name,
        FoodTable.colCategory: category.value,
        FoodTable.colCalories: caloriesPer100g,
        FoodTable.colProtein: proteinPer100g,
        FoodTable.colCarbs: carbsPer100g,
        FoodTable.colFats: fatsPer100g,
        FoodTable.colIsCustom: isCustom ? 1 : 0,
        FoodTable.colCreatedAt: createdAt.toIso8601String(),
      };

  factory Food.fromMap(Map<String, dynamic> map) => Food(
        id: map[FoodTable.colId] as int?,
        name: map[FoodTable.colName] as String,
        category: FoodCategory.fromValue(map[FoodTable.colCategory] as String?),
        caloriesPer100g:
            ((map[FoodTable.colCalories] as num?) ?? 0).toDouble(),
        proteinPer100g: ((map[FoodTable.colProtein] as num?) ?? 0).toDouble(),
        carbsPer100g: ((map[FoodTable.colCarbs] as num?) ?? 0).toDouble(),
        fatsPer100g: ((map[FoodTable.colFats] as num?) ?? 0).toDouble(),
        isCustom: ((map[FoodTable.colIsCustom] as int?) ?? 0) == 1,
        createdAt: DateTime.parse(map[FoodTable.colCreatedAt] as String),
      );

  Food copyWith({
    int? id,
    String? name,
    FoodCategory? category,
    double? caloriesPer100g,
    double? proteinPer100g,
    double? carbsPer100g,
    double? fatsPer100g,
    bool? isCustom,
  }) =>
      Food(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
        proteinPer100g: proteinPer100g ?? this.proteinPer100g,
        carbsPer100g: carbsPer100g ?? this.carbsPer100g,
        fatsPer100g: fatsPer100g ?? this.fatsPer100g,
        isCustom: isCustom ?? this.isCustom,
        createdAt: createdAt,
      );
}
