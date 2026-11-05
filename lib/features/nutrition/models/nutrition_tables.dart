import 'package:sqflite/sqflite.dart';

/// Toutes les tables du module Gestion Nutritionnelle (créées en version 11).
/// Chaque table utilise IF NOT EXISTS (rejouable sans danger) et des clés
/// étrangères vers `users(id)` en CASCADE. Aucune donnée utilisateur n'est
/// dupliquée : le profil nutritionnel complète le compte existant.

/// `nutrition_profiles` : un profil nutritionnel par utilisateur (UNIQUE).
class NutritionProfileTable {
  static const String tableName = 'nutrition_profiles';

  static const String colId = 'id';
  static const String colUserId = 'user_id';
  static const String colAge = 'age';
  static const String colSex = 'sex'; // 'male' / 'female'
  static const String colHeight = 'height_cm';
  static const String colWeight = 'weight_kg';
  static const String colActivityLevel = 'activity_level';
  static const String colGoal = 'goal';
  static const String colDailyCaloriesGoal = 'daily_calories_goal';
  static const String colProteinGoal = 'protein_goal';
  static const String colCarbsGoal = 'carbs_goal';
  static const String colFatsGoal = 'fats_goal';
  static const String colFoodPreferences = 'food_preferences';
  static const String colAllergies = 'allergies';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colUserId INTEGER NOT NULL UNIQUE,
        $colAge INTEGER,
        $colSex TEXT,
        $colHeight REAL,
        $colWeight REAL,
        $colActivityLevel TEXT NOT NULL DEFAULT 'moderate',
        $colGoal TEXT NOT NULL DEFAULT 'maintain',
        $colDailyCaloriesGoal REAL NOT NULL DEFAULT 0 CHECK($colDailyCaloriesGoal >= 0),
        $colProteinGoal REAL NOT NULL DEFAULT 0 CHECK($colProteinGoal >= 0),
        $colCarbsGoal REAL NOT NULL DEFAULT 0 CHECK($colCarbsGoal >= 0),
        $colFatsGoal REAL NOT NULL DEFAULT 0 CHECK($colFatsGoal >= 0),
        $colFoodPreferences TEXT NOT NULL DEFAULT '',
        $colAllergies TEXT NOT NULL DEFAULT '',
        $colCreatedAt TEXT NOT NULL,
        $colUpdatedAt TEXT NOT NULL,
        FOREIGN KEY ($colUserId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }
}

/// `foods` : catalogue d'aliments (valeurs pour 100 g). is_custom = ajout perso.
class FoodTable {
  static const String tableName = 'foods';

  static const String colId = 'id';
  static const String colName = 'name';
  static const String colCategory = 'category';
  static const String colCalories = 'calories_per_100g';
  static const String colProtein = 'protein_per_100g';
  static const String colCarbs = 'carbs_per_100g';
  static const String colFats = 'fats_per_100g';
  static const String colIsCustom = 'is_custom';
  static const String colCreatedAt = 'created_at';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colName TEXT NOT NULL,
        $colCategory TEXT NOT NULL DEFAULT 'other',
        $colCalories REAL NOT NULL DEFAULT 0 CHECK($colCalories >= 0),
        $colProtein REAL NOT NULL DEFAULT 0 CHECK($colProtein >= 0),
        $colCarbs REAL NOT NULL DEFAULT 0 CHECK($colCarbs >= 0),
        $colFats REAL NOT NULL DEFAULT 0 CHECK($colFats >= 0),
        $colIsCustom INTEGER NOT NULL DEFAULT 0,
        $colCreatedAt TEXT NOT NULL
      )
    ''');
  }
}

/// `meals` : un repas d'un utilisateur à une date et un type donnés.
class MealTable {
  static const String tableName = 'meals';

  static const String colId = 'id';
  static const String colUserId = 'user_id';
  static const String colMealType = 'meal_type';
  static const String colMealDate = 'meal_date'; // 'YYYY-MM-DD'
  static const String colCreatedAt = 'created_at';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colUserId INTEGER NOT NULL,
        $colMealType TEXT NOT NULL DEFAULT 'breakfast',
        $colMealDate TEXT NOT NULL,
        $colCreatedAt TEXT NOT NULL,
        FOREIGN KEY ($colUserId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }
}

/// `meal_items` : un aliment (+ quantité) dans un repas, avec valeurs calculées.
class MealItemTable {
  static const String tableName = 'meal_items';

  static const String colId = 'id';
  static const String colMealId = 'meal_id';
  static const String colFoodId = 'food_id';
  static const String colQuantity = 'quantity'; // grammes
  static const String colCalories = 'calories';
  static const String colProteins = 'proteins';
  static const String colCarbs = 'carbs';
  static const String colFats = 'fats';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colMealId INTEGER NOT NULL,
        $colFoodId INTEGER NOT NULL,
        $colQuantity REAL NOT NULL DEFAULT 0 CHECK($colQuantity > 0),
        $colCalories REAL NOT NULL DEFAULT 0,
        $colProteins REAL NOT NULL DEFAULT 0,
        $colCarbs REAL NOT NULL DEFAULT 0,
        $colFats REAL NOT NULL DEFAULT 0,
        FOREIGN KEY ($colMealId) REFERENCES ${MealTable.tableName}(id) ON DELETE CASCADE,
        FOREIGN KEY ($colFoodId) REFERENCES ${FoodTable.tableName}(id) ON DELETE CASCADE
      )
    ''');
  }
}

/// `weight_history` : relevés de poids datés.
class WeightHistoryTable {
  static const String tableName = 'weight_history';

  static const String colId = 'id';
  static const String colUserId = 'user_id';
  static const String colWeight = 'weight';
  static const String colRecordedAt = 'recorded_at';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colUserId INTEGER NOT NULL,
        $colWeight REAL NOT NULL CHECK($colWeight > 0),
        $colRecordedAt TEXT NOT NULL,
        FOREIGN KEY ($colUserId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }
}

/// `water_tracking` : prises d'eau (en millilitres).
class WaterTrackingTable {
  static const String tableName = 'water_tracking';

  static const String colId = 'id';
  static const String colUserId = 'user_id';
  static const String colQuantityMl = 'quantity_ml';
  static const String colRecordedAt = 'recorded_at';

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        $colId INTEGER PRIMARY KEY AUTOINCREMENT,
        $colUserId INTEGER NOT NULL,
        $colQuantityMl REAL NOT NULL CHECK($colQuantityMl > 0),
        $colRecordedAt TEXT NOT NULL,
        FOREIGN KEY ($colUserId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }
}

/// Crée toutes les tables nutrition (appelé par DatabaseHelper).
Future<void> createNutritionTables(Database db) async {
  await NutritionProfileTable.createTable(db);
  await FoodTable.createTable(db);
  await MealTable.createTable(db);
  await MealItemTable.createTable(db);
  await WeightHistoryTable.createTable(db);
  await WaterTrackingTable.createTable(db);
}
