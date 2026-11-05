import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/session/permissions.dart';
import '../../users/services/user_service.dart' show AuthException;
import '../models/equipment_category.dart';
import '../models/gym.dart';
import '../models/gym_equipment.dart';
import '../models/gym_equipment_table.dart';
import 'gym_service.dart';

/// CRUD des équipements d'une salle.
class GymEquipmentService {
  GymEquipmentService._();
  static final GymEquipmentService instance = GymEquipmentService._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  // ---------- Droits ----------

  /// Permission manageGymEquipment ET (admin ou propriétaire de la salle).
  bool canManage(Gym gym) =>
      Permissions.currentCan(Permission.manageGymEquipment) &&
      GymService.instance.isOwnerOrAdmin(gym);

  Future<void> _requireManage(int gymId) async {
    final gym = await GymService.instance.getById(gymId);
    if (gym == null) throw AuthException('Salle introuvable.');
    if (!canManage(gym)) throw AuthException('Action non autorisée.');
  }

  // ---------- Création ----------

  Future<GymEquipment> create(GymEquipment e) async {
    await _requireManage(e.gymId);
    final toSave = e.copyWith(name: e.name.trim(), createdAt: DateTime.now());
    _validate(toSave);

    final db = await _db;
    final id = await db.insert(GymEquipmentTable.tableName, toSave.toMap());
    return toSave.copyWith(id: id);
  }

  // ---------- Lecture ----------

  Future<List<GymEquipment>> getByGym(int gymId,
      {EquipmentCategory? category}) async {
    final db = await _db;
    final rows = await db.query(
      GymEquipmentTable.tableName,
      where: '${GymEquipmentTable.colGymId} = ?'
          "${category != null ? ' AND ${GymEquipmentTable.colCategory} = ?' : ''}",
      whereArgs: [gymId, ?category?.value],
      orderBy: '${GymEquipmentTable.colCategory}, '
          '${GymEquipmentTable.colName} COLLATE NOCASE',
    );
    return rows.map(GymEquipment.fromMap).toList();
  }

  Future<GymEquipment?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      GymEquipmentTable.tableName,
      where: '${GymEquipmentTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : GymEquipment.fromMap(rows.first);
  }

  /// Nombre total d'équipements d'une salle (somme des quantités).
  Future<int> countByGym(int gymId) async {
    final db = await _db;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(${GymEquipmentTable.colQuantity}), 0) '
      'FROM ${GymEquipmentTable.tableName} '
      'WHERE ${GymEquipmentTable.colGymId} = ?',
      [gymId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---------- Modification ----------

  Future<void> update(GymEquipment e) async {
    final existing = e.id == null ? null : await getById(e.id!);
    if (existing == null) throw AuthException('Équipement introuvable.');
    await _requireManage(existing.gymId);

    final clean = e.copyWith(name: e.name.trim());
    _validate(clean);

    // La salle et la date de création ne changent jamais.
    final map = clean.toMap()
      ..remove(GymEquipmentTable.colId)
      ..remove(GymEquipmentTable.colGymId)
      ..remove(GymEquipmentTable.colCreatedAt);

    final db = await _db;
    await db.update(
      GymEquipmentTable.tableName,
      map,
      where: '${GymEquipmentTable.colId} = ?',
      whereArgs: [existing.id],
    );
  }

  // ---------- Suppression ----------

  Future<void> delete(int id) async {
    final existing = await getById(id);
    if (existing == null) return;
    await _requireManage(existing.gymId);

    final db = await _db;
    await db.delete(
      GymEquipmentTable.tableName,
      where: '${GymEquipmentTable.colId} = ?',
      whereArgs: [id],
    );
  }

  // ---------- Interne ----------

  void _validate(GymEquipment e) {
    if (e.name.length < 2) {
      throw AuthException('Le nom doit contenir au moins 2 caractères.');
    }
    if (e.quantity < 1) {
      throw AuthException('La quantité doit être d\'au moins 1.');
    }
  }
}
