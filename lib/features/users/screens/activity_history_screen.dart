import 'package:flutter/material.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/xp_card.dart';
import '../models/activity_log.dart';
import '../models/badges.dart';
import '../models/level_system.dart';
import '../models/user.dart';
import '../services/user_service.dart';
import '../services/xp_service.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  User? _user;
  List<ActivityLog> _logs = [];
  int _loginDays = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = SessionManager.instance.currentUser;
      if (me == null) return;

      final user = await UserService.instance.getById(me.id!);
      final logs = await XpService.instance.getHistory(me.id!);
      final days = await XpService.instance.countByType(me.id!, 'login');

      if (!mounted) return;
      setState(() {
        _user = user ?? me;
        _logs = logs;
        _loginDays = days;
      });
    } catch (e, s) {
      debugPrint('ERREUR PROGRESSION : $e\n$s');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  IconData _iconFor(String type) {
    switch (type) {
      case 'registration':
        return Icons.waving_hand;
      case 'login':
        return Icons.login;
      case 'photo':
        return Icons.photo_camera;
      case 'sport_profile':
        return Icons.fitness_center;
      case 'profile_complete':
        return Icons.verified;
      default:
        return Icons.bolt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFFCFAFE),
        appBar: AppBar(
          title: const Text('Ma progression'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Badges'),
              Tab(text: 'Historique'),
            ],
          ),
        ),
        body: _loading || user == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildXpCard(user),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildBadgesTab(user),
                        _buildHistoryTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildXpCard(User user) {
    final info = LevelSystem.fromXp(user.xp);
    return XpCard(
      level: info.level,
      title: info.title,
      totalXp: user.xp,
      xpInLevel: info.xpInLevel,
      xpForNext: info.xpForNext,
    );
  }

  // ---------- Onglet Badges ----------

  Widget _buildBadgesTab(User user) {
    final badges = BadgeCatalog.badgesFor(user, _loginDays);
    final earned = badges.where((b) => b.earned).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '$earned / ${badges.length} badges obtenus',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: badges.map(_buildBadgeCard).toList(),
        ),
      ],
    );
  }

  Widget _buildBadgeCard(AppBadge badge) {
    final color = badge.earned ? AppTheme.purpleLight : Colors.grey;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: badge.earned ? Colors.white : const Color(0xFFF1EFF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: badge.earned
              ? AppTheme.purpleLight.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(badge.earned ? badge.icon : Icons.lock_outline,
              size: 34, color: color),
          const SizedBox(height: 8),
          Text(
            badge.label,
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            badge.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  // ---------- Onglet Historique ----------

  Widget _buildHistoryTab() {
    if (_logs.isEmpty) {
      return const Center(
        child: Text('Aucune activité pour le moment.',
            style: TextStyle(color: AppTheme.textSecondary)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: _logs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final log = _logs[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: AppTheme.purpleLight.withValues(alpha: 0.12),
            child: Icon(_iconFor(log.type), color: AppTheme.purpleLight),
          ),
          title: Text(log.description),
          subtitle: Text(_fmtDateTime(log.createdAt)),
          trailing: Text(
            '+${log.xp} XP',
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}