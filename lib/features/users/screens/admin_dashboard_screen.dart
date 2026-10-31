import 'package:flutter/material.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/widgets/app_loader.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import '../models/user_status.dart';
import '../services/user_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Palette MyGym
  static const _violetDark = Color(0xFF4C378E);
  static const _pink = Color(0xFFD43DA7);
  static const _grayLight = Color(0xFFEFEDF5);
  static const _lilac = Color(0xFFE8D8FC);
  static const _violet = Color(0xFFA86BEE);
  static const _textSecondary = Color(0xFF7A7390);

  List<User> _users = [];
  bool _loading = true;
  String _search = '';

  User? get _me => SessionManager.instance.currentUser;
  bool get _isAdmin => _me?.role == UserRole.admin;

  @override
  void initState() {
    super.initState();
    if (_isAdmin) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await UserService.instance.getAll();
      if (!mounted) return;
      setState(() => _users = users);
    } catch (e, s) {
      debugPrint('ERREUR DASHBOARD : $e\n$s');
      _snack('Erreur de chargement : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _violetDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  /// Exécute une action, affiche un message, puis recharge la liste.
  Future<void> _run(Future<void> Function() action, String message) async {
    try {
      await action();
      _snack(message);
      await _load();
    } catch (e, s) {
      debugPrint('ERREUR ACTION ADMIN : $e\n$s');
      _snack('Erreur : $e');
    }
  }

  // ---------- Actions ----------

  Future<void> _changeRole(User u) async {
    final role = await showDialog<UserRole>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Rôle de ${u.fullName}',
            style: const TextStyle(
                color: _violetDark, fontWeight: FontWeight.bold)),
        children: UserRole.values
            .map((r) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, r),
                  child: Row(
                    children: [
                      Icon(_roleIcon(r), color: _violet, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(r.label)),
                      if (r == u.role)
                        const Icon(Icons.check_circle, color: _pink),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
    if (role == null || role == u.role) return;
    await _run(() => UserService.instance.setRole(u.id!, role),
        'Rôle modifié : ${role.label}.');
  }

  Future<void> _delete(User u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Supprimer ce compte ?',
            style:
                TextStyle(color: _violetDark, fontWeight: FontWeight.bold)),
        content:
            Text('${u.fullName} (${u.email}) sera supprimé définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => UserService.instance.delete(u.id!), 'Compte supprimé.');
  }

  // ---------- Helpers visuels ----------

  Color _statusColor(UserStatus s) {
    switch (s) {
      case UserStatus.active:
        return const Color(0xFF2E9E6B);
      case UserStatus.pending:
        return const Color(0xFFE8920C);
      case UserStatus.disabled:
        return const Color(0xFFD64545);
    }
  }

  IconData _roleIcon(UserRole r) {
    switch (r) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.gymManager:
        return Icons.storefront;
      case UserRole.nutritionist:
        return Icons.restaurant_menu;
      case UserRole.coach:
        return Icons.sports;
      case UserRole.member:
        return Icons.person;
    }
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: _grayLight,
        appBar: AppBar(
          title: const Text('Accès refusé'),
          backgroundColor: _violetDark,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Cette page est réservée à l\'administrateur.'),
        ),
      );
    }

    final pending =
        _users.where((u) => u.status == UserStatus.pending).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _grayLight,
        body: Column(
          children: [
            _buildHeader(),
            _buildTabBar(pending.length),
            Expanded(
              child: _loading
                  ? const Center(child: AppLoader(size: 48, color: _pink))
                  : TabBarView(
                      children: [
                        _buildPendingTab(pending),
                        _buildUsersTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- En-tête + statistiques ----------

  Widget _buildHeader() {
    int count(UserStatus s) => _users.where((u) => u.status == s).length;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_violetDark, _violet],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 22),
          child: Column(
            children: [
              Row(
                children: [
                  if (Navigator.canPop(context))
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    )
                  else
                    const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tableau de bord',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Bonjour, ${_me?.firstName ?? ''}',
                          style: TextStyle(
                            color: _lilac.withValues(alpha: 0.95),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    tooltip: 'Actualiser',
                    onPressed: _load,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    _stat('Total', _users.length, Icons.groups, Colors.white),
                    _stat('Actifs', count(UserStatus.active),
                        Icons.check_circle, const Color(0xFF7DF0B8)),
                    _stat('Attente', count(UserStatus.pending),
                        Icons.hourglass_bottom, const Color(0xFFFFD27A)),
                    _stat('Désact.', count(UserStatus.disabled), Icons.block,
                        const Color(0xFFFF9C9C)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text('$value',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(
                    color: _lilac.withValues(alpha: 0.95), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ---------- Onglets ----------

  Widget _buildTabBar(int pendingCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _lilac,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(colors: [_violetDark, _violet]),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: _violetDark,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: [
          Tab(height: 38, text: 'En attente ($pendingCount)'),
          const Tab(height: 38, text: 'Utilisateurs'),
        ],
      ),
    );
  }

  // ---------- Onglet "En attente" ----------

  Widget _buildPendingTab(List<User> pending) {
    if (pending.isEmpty) {
      return _emptyState(
        Icons.verified_user_outlined,
        'Aucun compte en attente de validation.',
      );
    }
    return RefreshIndicator(
      color: _pink,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: pending.length,
        itemBuilder: (_, i) => _buildPendingCard(pending[i]),
      ),
    );
  }

  Widget _buildPendingCard(User u) {
    final roleText = u.coachType == null
        ? u.role.label
        : '${u.role.label} · ${u.coachType!.label}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(u, 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.fullName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _violetDark)),
                    const SizedBox(height: 2),
                    Text(u.email,
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 13)),
                    Text(u.phone,
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _pill(roleText, _violet, icon: _roleIcon(u.role)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD64545),
                    side: const BorderSide(color: Color(0xFFD64545)),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Refuser'),
                  onPressed: () => _run(
                    () => UserService.instance
                        .setStatus(u.id!, UserStatus.disabled),
                    'Compte refusé.',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Valider'),
                  onPressed: () => _run(
                    () => UserService.instance
                        .setStatus(u.id!, UserStatus.active),
                    'Compte validé.',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Onglet "Utilisateurs" ----------

  Widget _buildUsersTab() {
    final q = _search.trim().toLowerCase();
    final list = _users.where((u) {
      if (q.isEmpty) return true;
      return u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Rechercher un nom ou un email',
              hintStyle: const TextStyle(color: _textSecondary),
              prefixIcon: const Icon(Icons.search, color: _violet),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: _violet, width: 1.6),
              ),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? _emptyState(Icons.search_off, 'Aucun utilisateur trouvé.')
              : RefreshIndicator(
                  color: _pink,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _buildUserTile(list[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildUserTile(User u) {
    final isMe = u.id == _me?.id;
    final color = _statusColor(u.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _avatar(u, 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isMe ? '${u.fullName} (vous)' : u.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _violetDark)),
                const SizedBox(height: 2),
                Text(u.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: _textSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _pill(u.role.label, _violet, icon: _roleIcon(u.role)),
                    _pill(u.status.label, color),
                  ],
                ),
              ],
            ),
          ),
          // L'admin ne peut pas se modifier lui-même (évite de se bloquer).
          if (!isMe)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: _violetDark),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              onSelected: (action) {
                switch (action) {
                  case 'role':
                    _changeRole(u);
                    break;
                  case 'toggle':
                    final newStatus = u.status == UserStatus.active
                        ? UserStatus.disabled
                        : UserStatus.active;
                    _run(
                      () => UserService.instance.setStatus(u.id!, newStatus),
                      newStatus == UserStatus.active
                          ? 'Compte activé.'
                          : 'Compte désactivé.',
                    );
                    break;
                  case 'delete':
                    _delete(u);
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'role',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.swap_horiz, color: _violet),
                    title: Text('Changer le rôle'),
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                        u.status == UserStatus.active
                            ? Icons.block
                            : Icons.check_circle_outline,
                        color: _violet),
                    title: Text(u.status == UserStatus.active
                        ? 'Désactiver'
                        : 'Activer'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title:
                        Text('Supprimer', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            )
          else
            const SizedBox(width: 12),
        ],
      ),
    );
  }

  // ---------- Petits composants ----------

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _violetDark.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      );

  Widget _avatar(User u, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _lilac,
      child: Text(
        u.firstName.isEmpty ? '?' : u.firstName[0].toUpperCase(),
        style: TextStyle(
          color: _violetDark,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }

  Widget _pill(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration:
                const BoxDecoration(color: _lilac, shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: _violet),
          ),
          const SizedBox(height: 14),
          Text(message, style: const TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }
}