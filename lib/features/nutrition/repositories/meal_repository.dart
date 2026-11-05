import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/session/permissions.dart';
import '../../../core/session/session_manager.dart';
import '../../users/models/user.dart';
import '../../users/services/user_service.dart' show AuthException;
import '../models/food.dart';
import '../models/meal.dart';
import '../models/meal_item.dart';
import '../models/nutrition_enums.dart';
import '../models/nutrition_tables.dart';

/// Totaux nutritionnels d'une journée (ou d'un ensemble de repas).
class NutritionTotals {
  final double calories;
  final double proteins;
  final double carbs;
  final double fats;
  const NutritionTotals({
    this.calories = 0,
    this.proteins = 0,
    this.carbs = 0,
    this.fats = 0,
  });
}

/// Accès aux repas et à leurs aliments (toujours ceux de l'utilisateur connecté).
class MealRepository {
  MealRepository._();
  static final MealRepository instance = MealRepository._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  User _requireUser() {
    final user = SessionManager.instance.currentUser;
    if (user == null || !Permissions.currentCan(Permission.viewNutrition)) {
      throw AuthException('Accès non autorisé.');
    }
    return user;
  }

  // ---------- Lecture ----------

  /// Repas de l'utilisateur pour une date, avec leurs aliments.
  Future<List<Meal>> getMealsForDate(DateTime date) async {
    final user = _requireUser();
    final db = await _db;
    final rows = await db.query(
      MealTable.tableName,
      where: '${MealTable.colUserId} = ? AND ${MealTable.colMealDate} = ?',
      whereArgs: [user.id, Meal.dateKey(date)],
      orderBy: '${MealTable.colCreatedAt} ASC',
    );
    final meals = <Meal>[];
    for (final row in rows) {
      final meal = Meal.fromMap(row);
      final items = await _itemsFor(db, meal.id!);
      meals.add(meal.copyWith(items: items));
    }
    // Ordonne par type de repas (petit-déj -> dîner).
    meals.sort((a, b) => a.type.index.compareTo(b.type.index));
    return meals;
  }

  Future<Meal?> getMeal(int mealId) async {
    final user = _requireUser();
    final db = await _db;
    final rows = await db.query(
      MealTable.tableName,
      where: '${MealTable.colId} = ? AND ${MealTable.colUserId} = ?',
      whereArgs: [mealId, user.id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final items = await _itemsFor(db, mealId);
    return Meal.fromMap(rows.first, items: items);
  }

  Future<List<MealItem>> _itemsFor(DatabaseExecutor db, int mealId) async {
    final rows = await db.rawQuery(
      'SELECT mi.*, f.${FoodTable.colName} AS food_name '
      'FROM ${MealItemTable.tableName} mi '
      'JOIN ${FoodTable.tableName} f '
      'ON f.${FoodTable.colId} = mi.${MealItemTable.colFoodId} '
      'WHERE mi.${MealItemTable.colMealId} = ? '
      'ORDER BY mi.${MealItemTable.colId} ASC',
      [mealId],
    );
    return rows.map(MealItem.fromMap).toList();
  }

  /// Dates distinctes où l'utilisateur a enregistré des repas (historique).
  Future<List<DateTime>> getHistoryDates() async {
    final user = _requireUser();
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT DISTINCT ${MealTable.colMealDate} FROM ${MealTable.tableName} '
      'WHERE ${MealTable.colUserId} = ? '
      'ORDER BY ${MealTable.colMealDate} DESC',
      [user.id],
    );
    return rows
        .map((r) => DateTime.parse(r[MealTable.colMealDate] as String))
        .toList();
  }

  /// Totaux de la journée (somme de tous les repas de la date).
  Future<NutritionTotals> totalsForDate(DateTime date) async {
    final user = _requireUser();
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT '
      'COALESCE(SUM(mi.${MealItemTable.colCalories}),0) AS c, '
      'COALESCE(SUM(mi.${MealItemTable.colProteins}),0) AS p, '
      'COALESCE(SUM(mi.${MealItemTable.colCarbs}),0) AS g, '
      'COALESCE(SUM(mi.${MealItemTable.colFats}),0) AS l '
      'FROM ${MealItemTable.tableName} mi '
      'JOIN ${MealTable.tableName} m ON m.${MealTable.colId} = mi.${MealItemTable.colMealId} '
      'WHERE m.${MealTable.colUserId} = ? AND m.${MealTable.colMealDate} = ?',
      [user.id, Meal.dateKey(date)],
    );
    final r = rows.first;
    return NutritionTotals(
      calories: (r['c'] as num).toDouble(),
      proteins: (r['p'] as num).toDouble(),
      carbs: (r['g'] as num).toDouble(),
      fats: (r['l'] as num).toDouble(),
    );
  }

  // ---------- Écriture (transactions multi-tables) ----------

  /// Crée un repas et ses aliments en une seule transaction.
  Future<int> createMeal({
    required MealType type,
    required DateTime date,
    required List<MealItem> items,
  }) async {
    final user = _requireUser();
    if (items.isEmpty) {
      throw AuthException('Ajoutez au moins un aliment au repas.');
    }
    final db = await _db;
    return db.transaction<int>((txn) async {
      final mealId = await txn.insert(MealTable.tableName, {
        MealTable.colUserId: user.id,
        MealTable.colMealType: type.value,
        MealTable.colMealDate: Meal.dateKey(date),
        MealTable.colCreatedAt: DateTime.now().toIso8601String(),
      });
      for (final it in items) {
        await txn.insert(
            MealItemTable.tableName, it.copyWith(mealId: mealId).toMap());
      }
      return mealId;
    });
  }

  /// Met à jour un repas : type, date et liste d'aliments (remplacée).
  Future<void> updateMeal({
    required int mealId,
    required MealType type,
    required DateTime date,
    required List<MealItem> items,
  }) async {
    final user = _requireUser();
    if (items.isEmpty) {
      throw AuthException('Un repas doit contenir au moins un aliment.');
    }
    final db = await _db;
    await db.transaction((txn) async {
      final owned = await txn.query(
        MealTable.tableName,
        columns: [MealTable.colId],
        where: '${MealTable.colId} = ? AND ${MealTable.colUserId} = ?',
        whereArgs: [mealId, user.id],
        limit: 1,
      );
      if (owned.isEmpty) throw AuthException('Repas introuvable.');

      await txn.update(
        MealTable.tableName,
        {
          MealTable.colMealType: type.value,
          MealTable.colMealDate: Meal.dateKey(date),
        },
        where: '${MealTable.colId} = ?',
        whereArgs: [mealId],
      );
      await txn.delete(MealItemTable.tableName,
          where: '${MealItemTable.colMealId} = ?', whereArgs: [mealId]);
      for (final it in items) {
        await txn.insert(
            MealItemTable.tableName, it.copyWith(mealId: mealId).toMap());
      }
    });
  }

  Future<void> deleteMeal(int mealId) async {
    final user = _requireUser();
    final db = await _db;
    await db.delete(
      MealTable.tableName,
      where: '${MealTable.colId} = ? AND ${MealTable.colUserId} = ?',
      whereArgs: [mealId, user.id],
    );
  }

  /// Vérifie si un ou plusieurs aliments correspondent à une allergie déclarée.
  /// Renvoie les noms d'aliments concernés (pour avertir l'utilisateur).
  static List<String> matchAllergies(List<Food> foods, List<String> allergies) {
    if (allergies.isEmpty) return const [];
    final hits = <String>[];
    for (final f in foods) {
      final name = f.name.toLowerCase();
      if (allergies.any((a) => name.contains(a))) hits.add(f.name);
    }
    return hits;
  }
}
