import 'meal_item.dart';
import 'nutrition_enums.dart';
import 'nutrition_tables.dart';

/// Un repas : un type (petit-déj, déjeuner…) à une date, avec ses aliments.
class Meal {
  final int? id;
  final int userId;
  final MealType type;
  final DateTime date; // jour du repas (sans heure)
  final DateTime createdAt;

  // Chargés à part (lecture seule).
  final List<MealItem> items;

  const Meal({
    this.id,
    required this.userId,
    required this.type,
    required this.date,
    required this.createdAt,
    this.items = const [],
  });

  // ----- Totaux calculés à partir des aliments du repas -----
  double get totalCalories =>
      items.fold(0, (sum, it) => sum + it.calories);
  double get totalProteins =>
      items.fold(0, (sum, it) => sum + it.proteins);
  double get totalCarbs => items.fold(0, (sum, it) => sum + it.carbs);
  double get totalFats => items.fold(0, (sum, it) => sum + it.fats);

  /// Date stockée en base au format 'YYYY-MM-DD'.
  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toMap() => {
        if (id != null) MealTable.colId: id,
        MealTable.colUserId: userId,
        MealTable.colMealType: type.value,
        MealTable.colMealDate: dateKey(date),
        MealTable.colCreatedAt: createdAt.toIso8601String(),
      };

  factory Meal.fromMap(Map<String, dynamic> map, {List<MealItem> items = const []}) =>
      Meal(
        id: map[MealTable.colId] as int?,
        userId: map[MealTable.colUserId] as int,
        type: MealType.fromValue(map[MealTable.colMealType] as String?),
        date: DateTime.parse(map[MealTable.colMealDate] as String),
        createdAt: DateTime.parse(map[MealTable.colCreatedAt] as String),
        items: items,
      );

  Meal copyWith({MealType? type, DateTime? date, List<MealItem>? items}) => Meal(
        id: id,
        userId: userId,
        type: type ?? this.type,
        date: date ?? this.date,
        createdAt: createdAt,
        items: items ?? this.items,
      );
}
