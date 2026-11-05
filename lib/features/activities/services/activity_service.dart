import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/session/permissions.dart';
import '../../../core/session/session_manager.dart';
import '../../gyms/models/gym.dart';
import '../../gyms/models/gym_table.dart';
import '../../gyms/services/gym_service.dart';
import '../../users/models/user_role.dart';
import '../../users/services/user_service.dart' show AuthException;
import '../models/activity.dart';
import '../models/activity_session_table.dart';
import '../models/activity_table.dart';

/// CRUD des activités sportives + vérification des droits.
///
/// Une activité appartient à une salle : seul le responsable propriétaire de la
/// salle (ou l'administrateur) peut la créer, la modifier ou la supprimer.
class ActivityService {
  ActivityService._();
  static final ActivityService instance = ActivityService._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  static const String _table = ActivityTable.tableName;

  /// Activité + nom/ville de la salle + nombre de séances planifiées.
  static const String _select =
      'SELECT a.*, g.${GymTable.colName} AS gym_name, '
      'g.${GymTable.colCity} AS gym_city, '
      '(SELECT COUNT(*) FROM ${ActivitySessionTable.tableName} s '
      'WHERE s.${ActivitySessionTable.colActivityId} = a.${ActivityTable.colId}) '
      'AS session_count '
      'FROM $_table a '
      'JOIN ${GymTable.tableName} g '
      'ON g.${GymTable.colId} = a.${ActivityTable.colGymId} ';

  // ---------- Droits ----------

  /// Peut gérer les activités de cette salle ? (permission + propriété)
  bool canManage(Gym gym) =>
      Permissions.currentCan(Permission.manageActivities) &&
      GymService.instance.isOwnerOrAdmin(gym);

  Future<Gym> _requireManager(int gymId) async {
    final gym = await GymService.instance.getById(gymId);
    if (gym == null) throw AuthException('Salle introuvable.');
    if (!canManage(gym)) throw AuthException('Action non autorisée.');
    return gym;
  }

  void _requireViewer() {
    if (!Permissions.currentCan(Permission.viewActivities)) {
      throw AuthException('Accès non autorisé.');
    }
  }

  // ---------- Lecture ----------

  /// Les salles que le responsable connecté peut gérer (pour choisir une salle).
  Future<List<Gym>> getManageableGyms() async {
    final user = SessionManager.instance.currentUser;
    if (user == null || !Permissions.currentCan(Permission.manageActivities)) {
      return [];
    }
    return GymService.instance.getAll(
      ownerId: user.role == UserRole.admin ? null : user.id,
    );
  }

  Future<Activity?> getById(int id) async {
    _requireViewer();
    final db = await _db;
    final rows = await db.rawQuery(
      '$_select WHERE a.${ActivityTable.colId} = ? LIMIT 1',
      [id],
    );
    return rows.isEmpty ? null : Activity.fromMap(rows.first);
  }

  /// Activités d'une salle (recherche facultative sur nom / catégorie).
  Future<List<Activity>> getForGym(int gymId, {String search = ''}) async {
    _requireViewer();
    final where = <String>['a.${ActivityTable.colGymId} = ?'];
    final args = <Object?>[gymId];
    final q = search.trim();
    if (q.isNotEmpty) {
      where.add('(a.${ActivityTable.colName} LIKE ? OR '
          'a.${ActivityTable.colCategory} LIKE ?)');
      args.addAll(['%$q%', '%$q%']);
    }
    final db = await _db;
    final rows = await db.rawQuery(
      '$_select WHERE ${where.join(' AND ')} '
      'ORDER BY a.${ActivityTable.colName} COLLATE NOCASE',
      args,
    );
    return rows.map(Activity.fromMap).toList();
  }

  // ---------- Création / modification / suppression ----------

  /// Crée une activité dans une salle gérée par le responsable connecté.
  Future<Activity> create(Activity activity) async {
    await _requireManager(activity.gymId);
    final clean = _validated(activity);
    final db = await _db;
    await _ensureNameFree(db, clean.gymId, clean.name);
    final id = await db.insert(_table, clean.toMap());
    return clean.copyWith(id: id);
  }

  /// Met à jour une activité. La salle et la date de création ne changent pas.
  Future<void> update(Activity activity) async {
    final existing = activity.id == null ? null : await getById(activity.id!);
    if (existing == null) throw AuthException('Activité introuvable.');
    await _requireManager(existing.gymId);

    final clean = _validated(activity.copyWith(gymId: existing.gymId));
    final db = await _db;
    await _ensureNameFree(db, existing.gymId, clean.name, excludeId: existing.id);

    final map = clean.toMap()
      ..remove(ActivityTable.colId)
      ..remove(ActivityTable.colGymId)
      ..remove(ActivityTable.colCreatedAt);
    await db.update(
      _table,
      map,
      where: '${ActivityTable.colId} = ?',
      whereArgs: [existing.id],
    );
  }

  /// Supprime une activité (ses séances et réservations partent en CASCADE).
  Future<void> delete(int id) async {
    final existing = await getById(id);
    if (existing == null) return;
    await _requireManager(existing.gymId);
    final db = await _db;
    await db.delete(
      _table,
      where: '${ActivityTable.colId} = ?',
      whereArgs: [id],
    );
  }

  // ---------- Interne ----------

  /// Règles de validation des champs (nom, durée).
  Activity _validated(Activity a) {
    final name = a.name.trim();
    if (name.length < 3) {
      throw AuthException('Le nom doit contenir au moins 3 caractères.');
    }
    if (a.durationMin <= 0 || a.durationMin > 600) {
      throw AuthException('La durée doit être comprise entre 1 et 600 minutes.');
    }
    return a.copyWith(
      name: name,
      description: a.description.trim(),
      objective: a.objective.trim(),
    );
  }

  /// Vérifie qu'aucune autre activité de la salle ne porte déjà ce nom.
  Future<void> _ensureNameFree(Database db, int gymId, String name,
      {int? excludeId}) async {
    final rows = await db.query(
      _table,
      columns: [ActivityTable.colId],
      where: 'LOWER(${ActivityTable.colName}) = ? AND '
          '${ActivityTable.colGymId} = ?'
          "${excludeId != null ? ' AND ${ActivityTable.colId} != ?' : ''}",
      whereArgs: [
        name.toLowerCase(),
        gymId,
        ?excludeId,
      ],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      throw AuthException('Une activité porte déjà ce nom dans cette salle.');
    }
  }
}
