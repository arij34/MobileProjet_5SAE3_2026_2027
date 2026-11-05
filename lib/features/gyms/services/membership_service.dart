import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/session/permissions.dart';
import '../../../core/session/session_manager.dart';
import '../../users/models/user.dart';
import '../../users/models/user_role.dart';
import '../../users/models/user_table.dart';
import '../../users/services/user_service.dart' show AuthException;
import '../models/gym_membership.dart';
import '../models/gym_membership_table.dart';
import '../models/gym_table.dart';
import '../models/membership_status.dart';
import 'gym_service.dart';

/// Durées proposées et réductions (à ajuster ici, nulle part ailleurs).
class MembershipPricing {
  MembershipPricing._();

  /// durée en mois -> réduction (0.10 = 10 %)
  static const Map<int, double> discounts = {1: 0, 3: 0.10, 12: 0.20};

  static List<int> get durations => discounts.keys.toList();

  static double discountFor(int months) => discounts[months] ?? 0;

  /// Prix sans réduction.
  static double fullPrice(double monthly, int months) => monthly * months;

  /// Prix total après réduction, arrondi à 2 décimales.
  static double total(double monthly, int months) {
    final raw = fullPrice(monthly, months) * (1 - discountFor(months));
    return (raw * 100).round() / 100;
  }
}

/// Demandes d'adhésion (adhérent) et validation (responsable de salle).
class MembershipService {
  MembershipService._();
  static final MembershipService instance = MembershipService._();

  Future<Database> get _db => DatabaseHelper.instance.database;

  static const String _table = GymMembershipTable.tableName;

  /// Adhésion + nom de la salle + nom de l'adhérent.
  static const String _select =
      'SELECT m.*, g.${GymTable.colName} AS gym_name, '
      'g.${GymTable.colCity} AS gym_city, '
      "(u.${UserTable.colFirstName} || ' ' || u.${UserTable.colLastName}) "
      'AS member_name '
      'FROM $_table m '
      'JOIN ${GymTable.tableName} g '
      'ON g.${GymTable.colId} = m.${GymMembershipTable.colGymId} '
      'JOIN ${UserTable.tableName} u '
      'ON u.${UserTable.colId} = m.${GymMembershipTable.colUserId} ';

  // ---------- Droits ----------

  User _requireMember() {
    final user = SessionManager.instance.currentUser;
    if (user == null || !Permissions.currentCan(Permission.joinGym)) {
      throw AuthException('Action non autorisée.');
    }
    return user;
  }

  User _requireManager() {
    final user = SessionManager.instance.currentUser;
    if (user == null || !Permissions.currentCan(Permission.manageMemberships)) {
      throw AuthException('Action non autorisée.');
    }
    return user;
  }

  // ---------- Côté adhérent ----------

  /// Envoie une demande d'adhésion (statut "en attente"). Renvoie son id.
  Future<int> apply({required int gymId, required int months}) async {
    final user = _requireMember();
    if (!MembershipPricing.discounts.containsKey(months)) {
      throw AuthException('Durée invalide.');
    }

    final gym = await GymService.instance.getById(gymId);
    if (gym == null) throw AuthException('Salle introuvable.');
    if (!gym.isOpen) {
      throw AuthException('Cette salle n\'accepte pas de demandes pour le moment.');
    }

    await _expireOutdated();

    final db = await _db;
    final existing = await db.query(
      _table,
      where: '${GymMembershipTable.colUserId} = ? AND '
          '${GymMembershipTable.colGymId} = ? AND '
          '${GymMembershipTable.colStatus} IN (?, ?)',
      whereArgs: [
        user.id,
        gymId,
        MembershipStatus.pending.value,
        MembershipStatus.active.value,
      ],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw AuthException(
          'Vous avez déjà une demande ou une adhésion pour cette salle.');
    }

    final membership = GymMembership(
      userId: user.id!,
      gymId: gymId,
      months: months,
      priceTotal: MembershipPricing.total(gym.priceMonthly, months),
      createdAt: DateTime.now(),
    );
    return db.insert(_table, membership.toMap());
  }

  /// Mes demandes et adhésions, de la plus récente à la plus ancienne.
  Future<List<GymMembership>> getMine() async {
    final user = _requireMember();
    await _expireOutdated();
    final db = await _db;
    final rows = await db.rawQuery(
      '$_select WHERE m.${GymMembershipTable.colUserId} = ? '
      'ORDER BY m.${GymMembershipTable.colCreatedAt} DESC',
      [user.id],
    );
    return rows.map(GymMembership.fromMap).toList();
  }

  /// Pour chaque salle où j'ai une demande en attente ou une adhésion active :
  /// son statut (sert à remplacer le bouton "Postuler" dans le catalogue).
  Future<Map<int, MembershipStatus>> getStatusByGym() async {
    final user = SessionManager.instance.currentUser;
    if (user == null || !Permissions.currentCan(Permission.joinGym)) {
      return {};
    }
    await _expireOutdated();
    final db = await _db;
    final rows = await db.query(
      _table,
      columns: [GymMembershipTable.colGymId, GymMembershipTable.colStatus],
      where: '${GymMembershipTable.colUserId} = ? AND '
          '${GymMembershipTable.colStatus} IN (?, ?)',
      whereArgs: [
        user.id,
        MembershipStatus.pending.value,
        MembershipStatus.active.value,
      ],
    );
    final result = <int, MembershipStatus>{};
    for (final r in rows) {
      final gymId = r[GymMembershipTable.colGymId] as int;
      final status =
          MembershipStatus.fromValue(r[GymMembershipTable.colStatus] as String?);
      // "active" l'emporte sur "pending" si les deux existent.
      if (result[gymId] != MembershipStatus.active) result[gymId] = status;
    }
    return result;
  }

  /// Annule ma demande tant qu'elle est en attente.
  Future<void> cancel(int membershipId) async {
    final user = _requireMember();
    final db = await _db;
    final count = await db.update(
      _table,
      {GymMembershipTable.colStatus: MembershipStatus.cancelled.value},
      where: '${GymMembershipTable.colId} = ? AND '
          '${GymMembershipTable.colUserId} = ? AND '
          '${GymMembershipTable.colStatus} = ?',
      whereArgs: [membershipId, user.id, MembershipStatus.pending.value],
    );
    if (count == 0) {
      throw AuthException('Cette demande ne peut plus être annulée.');
    }
  }

  // ---------- Côté responsable ----------

  /// Demandes des salles du responsable connecté (toutes les salles pour l'admin).
  Future<List<GymMembership>> getRequests({MembershipStatus? status}) async {
    final user = _requireManager();
    await _expireOutdated();

    final where = <String>[];
    final args = <Object?>[];
    if (user.role != UserRole.admin) {
      where.add('g.${GymTable.colOwnerId} = ?');
      args.add(user.id);
    }
    if (status != null) {
      where.add('m.${GymMembershipTable.colStatus} = ?');
      args.add(status.value);
    }

    final db = await _db;
    final rows = await db.rawQuery(
      '$_select ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY m.${GymMembershipTable.colCreatedAt} DESC',
      args,
    );
    return rows.map(GymMembership.fromMap).toList();
  }

  /// Accepte une demande : début aujourd'hui, fin selon la durée, QR généré.
  Future<void> accept(int membershipId) async {
    final m = await _loadForManager(membershipId);
    if (m.status != MembershipStatus.pending) {
      throw AuthException('Cette demande a déjà été traitée.');
    }

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final lastDay = addMonths(start, m.months);
    // Valable jusqu'à la fin du dernier jour.
    final end = DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59);

    final db = await _db;
    final token = await _uniqueToken(db);
    await db.update(
      _table,
      {
        GymMembershipTable.colStatus: MembershipStatus.active.value,
        GymMembershipTable.colQrToken: token,
        GymMembershipTable.colStartDate: start.toIso8601String(),
        GymMembershipTable.colEndDate: end.toIso8601String(),
      },
      where: '${GymMembershipTable.colId} = ? AND '
          '${GymMembershipTable.colStatus} = ?',
      whereArgs: [membershipId, MembershipStatus.pending.value],
    );
  }

  Future<void> reject(int membershipId) async {
    final m = await _loadForManager(membershipId);
    if (m.status != MembershipStatus.pending) {
      throw AuthException('Cette demande a déjà été traitée.');
    }
    final db = await _db;
    await db.update(
      _table,
      {GymMembershipTable.colStatus: MembershipStatus.rejected.value},
      where: '${GymMembershipTable.colId} = ?',
      whereArgs: [membershipId],
    );
  }

  // ---------- Interne ----------

  /// Charge une adhésion ET vérifie que le responsable connecté est bien
  /// propriétaire de la salle concernée (ou administrateur).
  Future<GymMembership> _loadForManager(int membershipId) async {
    _requireManager();
    final db = await _db;
    final rows = await db.rawQuery(
      '$_select WHERE m.${GymMembershipTable.colId} = ? LIMIT 1',
      [membershipId],
    );
    if (rows.isEmpty) throw AuthException('Demande introuvable.');
    final m = GymMembership.fromMap(rows.first);

    final gym = await GymService.instance.getById(m.gymId);
    if (gym == null || !GymService.instance.isOwnerOrAdmin(gym)) {
      throw AuthException('Action non autorisée.');
    }
    return m;
  }

  /// Passe en "expirée" les adhésions actives dont la date de fin est dépassée.
  Future<void> _expireOutdated() async {
    final db = await _db;
    await db.update(
      _table,
      {GymMembershipTable.colStatus: MembershipStatus.expired.value},
      where: '${GymMembershipTable.colStatus} = ? AND '
          '${GymMembershipTable.colEndDate} IS NOT NULL AND '
          '${GymMembershipTable.colEndDate} < ?',
      whereArgs: [
        MembershipStatus.active.value,
        DateTime.now().toIso8601String(),
      ],
    );
  }

  /// Ajoute des mois sans déborder (31 janvier + 1 mois = 28 ou 29 février).
  static DateTime addMonths(DateTime d, int months) {
    final total = d.month - 1 + months;
    final year = d.year + total ~/ 12;
    final month = total % 12 + 1;
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, d.day > lastDayOfMonth ? lastDayOfMonth : d.day);
  }

  // Sans 0/O ni 1/I : plus facile à recopier à la main.
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Jeton aléatoire de 20 caractères (cryptographiquement sûr) : il ne se devine pas.
  String _generateToken() {
    final random = Random.secure();
    return List.generate(
      20,
      (_) => _alphabet[random.nextInt(_alphabet.length)],
    ).join();
  }

  Future<String> _uniqueToken(Database db) async {
    for (var i = 0; i < 5; i++) {
      final token = _generateToken();
      final rows = await db.query(
        _table,
        columns: [GymMembershipTable.colId],
        where: '${GymMembershipTable.colQrToken} = ?',
        whereArgs: [token],
        limit: 1,
      );
      if (rows.isEmpty) return token;
    }
    throw AuthException('Impossible de générer le code. Réessayez.');
  }
}
