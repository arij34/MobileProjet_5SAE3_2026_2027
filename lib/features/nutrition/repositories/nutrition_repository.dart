import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/session/permissions.dart';
import '../../../core/session/session_manager.dart';
import '../../users/models/user.dart';
import '../../users/services/user_service.dart' show AuthException;
import '../models/meal.dart';
import '../models/nutrition_enums.dart';
import '../models/nutrition_profile.dart';
import '../models/nutrition_tables.dart';
import '../models/weight_entry.dart';

/// Accès au profil nutritionnel, au suivi du poids et de l'eau.
class NutritionRepository {
  NutritionRepository._();
  static final NutritionRepository instance = NutritionRepository._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  User _requireUser() {
    final user = SessionManager.instance.currentUser;
    if (user == null || !Permissions.currentCan(Permission.viewNutrition)) {
      throw AuthException('Accès non autorisé.');
    }
    return user;
  }

  // ---------- Profil ----------

  /// Profil enregistré, ou `null` s'il n'existe pas encore.
  Future<NutritionProfile?> getProfile() async {
    final user = _requireUser();
    final db = await _db;
    final rows = await db.query(
      NutritionProfileTable.tableName,
      where: '${NutritionProfileTable.colUserId} = ?',
      whereArgs: [user.id],
      limit: 1,
    );
    return rows.isEmpty ? null : NutritionProfile.fromMap(rows.first);
  }

  /// Profil existant, ou un brouillon pré-rempli depuis le compte utilisateur
  /// (âge, sexe, taille, poids) — aucune donnée dupliquée tant que non enregistrée.
  Future<NutritionProfile> getOrDraftProfile() async {
    final existing = await getProfile();
    if (existing != null) return existing;
    final user = SessionManager.instance.currentUser!;
    final now = DateTime.now();
    return NutritionProfile(
      userId: user.id!,
      age: user.age,
      sex: user.gender,
      heightCm: user.heightCm,
      weightKg: user.weightKg,
      goal: NutritionGoal.fromUserGoal(user.goal),
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Insère ou met à jour le profil (une ligne par utilisateur, UNIQUE).
  Future<NutritionProfile> saveProfile(NutritionProfile profile) async {
    final user = _requireUser();
    if (profile.userId != user.id) {
      throw AuthException('Action non autorisée.');
    }
    final db = await _db;
    final now = DateTime.now();
    final existing = await db.query(
      NutritionProfileTable.tableName,
      columns: [NutritionProfileTable.colId],
      where: '${NutritionProfileTable.colUserId} = ?',
      whereArgs: [user.id],
      limit: 1,
    );
    final toSave = profile.copyWith(updatedAt: now);
    if (existing.isEmpty) {
      final map = toSave.toMap()
        ..[NutritionProfileTable.colCreatedAt] = now.toIso8601String();
      final id = await db.insert(NutritionProfileTable.tableName, map);
      return NutritionProfile.fromMap({...map, NutritionProfileTable.colId: id});
    } else {
      final map = toSave.toMap()
        ..remove(NutritionProfileTable.colId)
        ..remove(NutritionProfileTable.colUserId)
        ..remove(NutritionProfileTable.colCreatedAt);
      await db.update(
        NutritionProfileTable.tableName,
        map,
        where: '${NutritionProfileTable.colUserId} = ?',
        whereArgs: [user.id],
      );
      return (await getProfile())!;
    }
  }

  // ---------- Poids ----------

  Future<void> addWeight(double weight, {DateTime? at}) async {
    final user = _requireUser();
    if (weight <= 0) throw AuthException('Poids invalide.');
    final db = await _db;
    await db.insert(WeightHistoryTable.tableName, {
      WeightHistoryTable.colUserId: user.id,
      WeightHistoryTable.colWeight: weight,
      WeightHistoryTable.colRecordedAt: (at ?? DateTime.now()).toIso8601String(),
    });
  }

  /// Historique de poids (du plus ancien au plus récent, pour le graphe).
  Future<List<WeightEntry>> getWeightHistory() async {
    final user = _requireUser();
    final db = await _db;
    final rows = await db.query(
      WeightHistoryTable.tableName,
      where: '${WeightHistoryTable.colUserId} = ?',
      whereArgs: [user.id],
      orderBy: '${WeightHistoryTable.colRecordedAt} ASC',
    );
    return rows.map(WeightEntry.fromMap).toList();
  }

  Future<double?> latestWeight() async {
    final history = await getWeightHistory();
    return history.isEmpty ? null : history.last.weight;
  }

  // ---------- Eau ----------

  Future<void> addWater(double ml, {DateTime? at}) async {
    final user = _requireUser();
    if (ml <= 0) throw AuthException('Quantité invalide.');
    final db = await _db;
    await db.insert(WaterTrackingTable.tableName, {
      WaterTrackingTable.colUserId: user.id,
      WaterTrackingTable.colQuantityMl: ml,
      WaterTrackingTable.colRecordedAt:
          (at ?? DateTime.now()).toIso8601String(),
    });
  }

  /// Total d'eau bu pour une date (en millilitres).
  Future<double> waterForDate(DateTime date) async {
    final user = _requireUser();
    final db = await _db;
    final start = Meal.dateKey(date); // 'YYYY-MM-DD'
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(${WaterTrackingTable.colQuantityMl}),0) AS ml '
      'FROM ${WaterTrackingTable.tableName} '
      'WHERE ${WaterTrackingTable.colUserId} = ? '
      'AND substr(${WaterTrackingTable.colRecordedAt},1,10) = ?',
      [user.id, start],
    );
    return (rows.first['ml'] as num).toDouble();
  }
}
