import 'package:flutter/material.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/theme/app_theme.dart';
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> _changeRole(User u) async {
    final role = await showDialog<UserRole>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('Rôle de ${u.fullName}'),
        children: UserRole.values
            .map((r) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, r),
                  child: Row(
                    children: [
                      Expanded(child: Text(r.label)),
                      if (r == u.role)
                        const Icon(Icons.check, color: Colors.green),
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
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce compte ?'),
        content: Text('${u.fullName} (${u.email}) sera supprimé définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => UserService.instance.delete(u.id!), 'Compte supprimé.');
  }

  Color _statusColor(UserStatus s) {
    switch (s) {
      case UserStatus.active:
        return Colors.green;
      case UserStatus.pending:
        return Colors.orange;
      case UserStatus.disabled:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Accès refusé')),
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
        backgroundColor: const Color(0xFFFCFAFE),
        appBar: AppBar(
          title: const Text('Tableau de bord'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualiser',
              onPressed: _load,
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'En attente (${pending.length})'),
              const Tab(text: 'Utilisateurs'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildStats(),
                  Expanded(
                    child: TabBarView(
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

  // ---------- Statistiques ----------

  Widget _buildStats() {
    int count(UserStatus s) => _users.where((u) => u.status == s).length;

    Widget stat(String label, int value, Color color) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text('$value',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: color)),
                const SizedBox(height: 2),
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      child: Row(
        children: [
          stat('Total', _users.length, AppTheme.purpleLight),
          stat('Actifs', count(UserStatus.active), Colors.green),
          stat('En attente', count(UserStatus.pending), Colors.orange),
          stat('Désactivés', count(UserStatus.disabled), Colors.red),
        ],
      ),
    );
  }

  // ---------- Onglet "En attente" ----------

  Widget _buildPendingTab(List<User> pending) {
    if (pending.isEmpty) {
      return const Center(
        child: Text('Aucun compte en attente de validation.',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: pending.length,
      itemBuilder: (_, i) {
        final u = pending[i];
        final roleText = u.coachType == null
            ? u.role.label
            : '${u.role.label} · ${u.coachType!.label}';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.fullName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(u.email,
                    style: const TextStyle(color: AppTheme.textSecondary)),
                Text(u.phone,
                    style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 6),
                Chip(label: Text(roleText)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => _run(
                        () => UserService.instance
                            .setStatus(u.id!, UserStatus.disabled),
                        'Compte refusé.',
                      ),
                      child: const Text('Refuser'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => _run(
                        () => UserService.instance
                            .setStatus(u.id!, UserStatus.active),
                        'Compte validé.',
                      ),
                      child: const Text('Valider'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Rechercher un nom ou un email',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(color: Color(0xFFBDB6C8)),
              ),
            ),
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('Aucun utilisateur trouvé.'))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) => _buildUserTile(list[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildUserTile(User u) {
    final isMe = u.id == _me?.id;
    final color = _statusColor(u.status);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.purpleLight,
        child: Text(
          u.firstName.isEmpty ? '?' : u.firstName[0].toUpperCase(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(isMe ? '${u.fullName} (vous)' : u.fullName),
      subtitle: Text('${u.email}\n${u.role.label}'),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(u.status.label,
                style: TextStyle(color: color, fontSize: 11)),
          ),
          // L'admin ne peut pas se modifier lui-même (évite de se bloquer).
          if (!isMe)
            PopupMenuButton<String>(
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
                    value: 'role', child: Text('Changer le rôle')),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(u.status == UserStatus.active
                      ? 'Désactiver'
                      : 'Activer'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Supprimer',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}