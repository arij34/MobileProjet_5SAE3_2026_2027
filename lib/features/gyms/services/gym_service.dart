import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/session/permissions.dart';
import '../../../core/session/session_manager.dart';
import '../../users/models/user_role.dart';
import '../../users/services/user_service.dart' show AuthException;
import '../models/gym.dart';
import '../models/gym_status.dart';
import '../models/gym_table.dart';

/// Toutes les opérations sur les salles (CRUD) + vérification des droits.
class GymService {
  GymService._();
  static final GymService instance = GymService._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  // ---------- Droits ----------

  /// L'administrateur gère toutes les salles ; un responsable seulement les siennes.
  bool isOwnerOrAdmin(Gym gym) {
    final user = SessionManager.instance.currentUser;
    if (user == null) return false;
    return user.role == UserRole.admin || gym.ownerId == user.id;
  }

  /// Peut modifier / supprimer cette salle ?
  bool canEdit(Gym gym) =>
      Permissions.currentCan(Permission.manageGyms) && isOwnerOrAdmin(gym);

  // ---------- Création ----------

  /// Crée une salle. Le propriétaire est TOUJOURS l'utilisateur connecté.
  Future<Gym> create(Gym gym) async {
    final user = SessionManager.instance.currentUser;
    if (user == null || !Permissions.currentCan(Permission.manageGyms)) {
      throw AuthException('Action non autorisée.');
    }

    final toSave = gym.copyWith(
      ownerId: user.id!,
      name: gym.name.trim(),
      description: gym.description.trim(),
      address: gym.address.trim(),
      city: gym.city.trim(),
      phone: gym.phone.trim(),
      openingHours: gym.openingHours.trim(),
      createdAt: DateTime.now(),
    );
    await _validate(toSave);

    final db = await _db;
    final id = await db.insert(GymTable.tableName, toSave.toMap());
    return toSave.copyWith(id: id);
  }

  // ---------- Lecture ----------

  /// Liste des salles avec filtres facultatifs (tous combinables).
  Future<List<Gym>> getAll({
    String? search,
    String? city,
    double? maxPrice,
    GymStatus? status,
    int? ownerId,
  }) async {
    if (!Permissions.currentCan(Permission.viewGyms)) {
      throw AuthException('Accès non autorisé.');
    }

    final where = <String>[];
    final args = <Object?>[];

    if (search != null && search.trim().isNotEmpty) {
      final q = '%${search.trim()}%';
      where.add('(${GymTable.colName} LIKE ? OR '
          '${GymTable.colDescription} LIKE ? OR '
          '${GymTable.colCity} LIKE ?)');
      args.addAll([q, q, q]);
    }
    if (city != null && city.isNotEmpty) {
      where.add('${GymTable.colCity} = ?');
      args.add(city);
    }
    if (maxPrice != null) {
      where.add('${GymTable.colPriceMonthly} <= ?');
      args.add(maxPrice);
    }
    if (status != null) {
      where.add('${GymTable.colStatus} = ?');
      args.add(status.value);
    }
    if (ownerId != null) {
      where.add('${GymTable.colOwnerId} = ?');
      args.add(ownerId);
    }

    final db = await _db;
    final rows = await db.query(
      GymTable.tableName,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: '${GymTable.colName} COLLATE NOCASE',
    );
    return rows.map(Gym.fromMap).toList();
  }

  Future<Gym?> getById(int id) async {
    final db = await _db;
    final rows = await db.query(
      GymTable.tableName,
      where: '${GymTable.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Gym.fromMap(rows.first);
  }

  /// Villes distinctes (pour le filtre de la liste).
  Future<List<String>> getCities() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT DISTINCT ${GymTable.colCity} FROM ${GymTable.tableName} '
      'ORDER BY ${GymTable.colCity} COLLATE NOCASE',
    );
    return rows.map((r) => r[GymTable.colCity] as String).toList();
  }

  // ---------- Modification ----------

  /// Met à jour une salle. Le propriétaire et la date de création ne changent pas.
  Future<void> update(Gym gym) async {
    final existing = gym.id == null ? null : await getById(gym.id!);
    if (existing == null) throw AuthException('Salle introuvable.');
    if (!canEdit(existing)) throw AuthException('Action non autorisée.');

    final clean = gym.copyWith(
      name: gym.name.trim(),
      description: gym.description.trim(),
      address: gym.address.trim(),
      city: gym.city.trim(),
      phone: gym.phone.trim(),
      openingHours: gym.openingHours.trim(),
    );
    await _validate(clean, excludeId: existing.id);

    final map = clean.toMap()
      ..remove(GymTable.colId)
      ..remove(GymTable.colOwnerId)
      ..remove(GymTable.colCreatedAt);

    final db = await _db;
    await db.update(
      GymTable.tableName,
      map,
      where: '${GymTable.colId} = ?',
      whereArgs: [existing.id],
    );
  }

  // ---------- Suppression ----------

  /// Supprime la salle ; ses équipements partent avec elle (ON DELETE CASCADE).
  Future<void> delete(int id) async {
    final existing = await getById(id);
    if (existing == null) return;
    if (!canEdit(existing)) throw AuthException('Action non autorisée.');

    final db = await _db;
    await db.delete(
      GymTable.tableName,
      where: '${GymTable.colId} = ?',
      whereArgs: [id],
    );
  }

  // ---------- Interne ----------

  /// Règles métier : champs obligatoires, valeurs positives, nom unique par ville.
  Future<void> _validate(Gym g, {int? excludeId}) async {
    if (g.name.length < 3) {
      throw AuthException('Le nom doit contenir au moins 3 caractères.');
    }
    if (g.address.isEmpty || g.city.isEmpty) {
      throw AuthException('L\'adresse et la ville sont obligatoires.');
    }
    if (g.phone.isNotEmpty && !RegExp(r'^[0-9+ ]{8,15}$').hasMatch(g.phone)) {
      throw AuthException('Numéro de téléphone invalide.');
    }
    if (g.capacity < 0 || g.priceMonthly < 0) {
      throw AuthException('La capacité et le prix doivent être positifs.');
    }

    final db = await _db;
    final rows = await db.query(
      GymTable.tableName,
      where: 'LOWER(${GymTable.colName}) = ? AND '
          'LOWER(${GymTable.colCity}) = ?'
          "${excludeId != null ? ' AND ${GymTable.colId} != ?' : ''}",
      whereArgs: [g.name.toLowerCase(), g.city.toLowerCase(), ?excludeId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      throw AuthException('Une salle porte déjà ce nom dans cette ville.');
    }
  }
}
