import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/session/permissions.dart';
import '../../../core/session/session_manager.dart';
import '../../users/services/user_service.dart' show AuthException;
import '../models/food.dart';
import '../models/nutrition_enums.dart';
import '../models/nutrition_tables.dart';

/// Accès aux aliments (catalogue partagé + aliments personnalisés).
class FoodRepository {
  FoodRepository._();
  static final FoodRepository instance = FoodRepository._();

  Future<Database> get _db => DatabaseHelper.instance.database;
  static const String _table = FoodTable.tableName;

  void _requireUser() {
    final user = SessionManager.instance.currentUser;
    if (user == null || !Permissions.currentCan(Permission.viewNutrition)) {
      throw AuthException('Accès non autorisé.');
    }
  }

  /// Liste des aliments, avec recherche (nom) et filtre par catégorie.
  Future<List<Food>> getAll({String search = '', FoodCategory? category}) async {
    _requireUser();
    final where = <String>[];
    final args = <Object?>[];
    final q = search.trim();
    if (q.isNotEmpty) {
      where.add('${FoodTable.colName} LIKE ?');
      args.add('%$q%');
    }
    if (category != null) {
      where.add('${FoodTable.colCategory} = ?');
      args.add(category.value);
    }
    final db = await _db;
    final rows = await db.query(
      _table,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: '${FoodTable.colName} COLLATE NOCASE',
    );
    return rows.map(Food.fromMap).toList();
  }

  Future<Food?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(_table,
        where: '${FoodTable.colId} = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Food.fromMap(rows.first);
  }

  Future<Food> create(Food food) async {
    _requireUser();
    final clean = food.copyWith(name: food.name.trim(), isCustom: true);
    final db = await _db;
    final id = await db.insert(_table, clean.toMap());
    return clean.copyWith(id: id);
  }

  Future<void> update(Food food) async {
    _requireUser();
    if (food.id == null) throw AuthException('Aliment introuvable.');
    final db = await _db;
    final map = food.copyWith(name: food.name.trim()).toMap()
      ..remove(FoodTable.colId)
      ..remove(FoodTable.colCreatedAt);
    await db.update(_table, map,
        where: '${FoodTable.colId} = ?', whereArgs: [food.id]);
  }

  /// Supprime un aliment. Ses occurrences dans les repas partent en CASCADE.
  Future<void> delete(int id) async {
    _requireUser();
    final db = await _db;
    await db.delete(_table, where: '${FoodTable.colId} = ?', whereArgs: [id]);
  }

  /// Insère la liste d'aliments de démonstration si la table est vide.
  /// Données initiales clairement identifiées (valeurs pour 100 g, sources
  /// nutritionnelles usuelles).
  static Future<void> seedIfEmpty(Database db) async {
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_table'));
    if ((count ?? 0) > 0) return;

    final now = DateTime.now().toIso8601String();
    // name, category, kcal, prot, carbs, fats (pour 100 g)
    const seed = <List<dynamic>>[
      ['Poulet (blanc)', 'protein', 165.0, 31.0, 0.0, 3.6],
      ['Riz blanc cuit', 'grain', 130.0, 2.7, 28.0, 0.3],
      ['Œuf', 'protein', 155.0, 13.0, 1.1, 11.0],
      ['Banane', 'fruit', 89.0, 1.1, 23.0, 0.3],
      ['Flocons d\'avoine', 'grain', 389.0, 16.9, 66.0, 6.9],
      ['Brocoli', 'vegetable', 34.0, 2.8, 7.0, 0.4],
      ['Thon (au naturel)', 'protein', 116.0, 26.0, 0.0, 1.0],
      ['Lait demi-écrémé', 'dairy', 47.0, 3.4, 4.8, 1.6],
      ['Yaourt nature', 'dairy', 61.0, 3.5, 4.7, 3.3],
      ['Pâtes cuites', 'grain', 157.0, 5.8, 31.0, 0.9],
      ['Pomme', 'fruit', 52.0, 0.3, 14.0, 0.2],
      ['Amandes', 'fat', 579.0, 21.0, 22.0, 50.0],
      ['Saumon', 'protein', 208.0, 20.0, 0.0, 13.0],
      ['Pain complet', 'grain', 247.0, 13.0, 41.0, 3.4],
      ['Huile d\'olive', 'fat', 884.0, 0.0, 0.0, 100.0],
      ['Eau', 'drink', 0.0, 0.0, 0.0, 0.0],
    ];

    final batch = db.batch();
    for (final f in seed) {
      batch.insert(_table, {
        FoodTable.colName: f[0],
        FoodTable.colCategory: f[1],
        FoodTable.colCalories: f[2],
        FoodTable.colProtein: f[3],
        FoodTable.colCarbs: f[4],
        FoodTable.colFats: f[5],
        FoodTable.colIsCustom: 0,
        FoodTable.colCreatedAt: now,
      });
    }
    await batch.commit(noResult: true);
  }
}
