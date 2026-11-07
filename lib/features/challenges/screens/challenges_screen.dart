import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/dev/challenge_seeder.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/session/permissions.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/gradient_header.dart';
import '../models/challenge.dart';
import '../models/challenge_status.dart';
import '../models/participant_status.dart';
import '../services/challenge_service.dart';
import '../services/participation_service.dart';
import '../widgets/challenge_styles.dart';
import '../widgets/challenges_calendar.dart';
import '../../users/models/user_role.dart';
import '../../notifications/services/notification_service.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  List<Challenge> _challenges = const [];
  bool _loading = true;
  bool _seeding = false;
  int _memberTab = 0;
  List<MyChallenge> _myChallenges = const [];
  String? _error;

  bool get _canView => Permissions.currentCan(Permission.viewChallenges);
  bool get _canManage => Permissions.currentCan(Permission.manageChallenges);
  bool get _canUseDemoTools {
    final user = SessionManager.instance.currentUser;
    return kDebugMode &&
        user != null &&
        user.isActive &&
        user.role == UserRole.coach &&
        user.id != null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_canView) {
      setState(() => _loading = false);
      return;
    }
    try {
      final loaded = await ChallengeService.instance.getChallenges();
      final mine = Permissions.currentCan(Permission.joinChallenge)
          ? await ParticipationService.instance.getMyChallenges()
          : <MyChallenge>[];
      mine.sort((a, b) {
        int rank(ParticipantStatus status) => switch (status) {
          ParticipantStatus.joined => 0,
          ParticipantStatus.completed => 1,
          ParticipantStatus.abandoned => 2,
        };
        return rank(a.participation.status)
            .compareTo(rank(b.participation.status));
      });
      if (!mounted) return;
      setState(() {
        _challenges = loaded;
        _myChallenges = mine;
        _error = null;
        _loading = false;
      });
    } catch (e, s) {
      debugPrint('ERREUR LISTE CHALLENGES : $e\n$s');
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les challenges';
        _loading = false;
      });
    }
  }

  Future<void> _openForm() async {
    if (!_canManage) return;
    await Navigator.pushNamed(context, AppRoutes.challengeForm);
    if (mounted) await _load();
  }

  Future<void> _openAiGenerator() async {
    if (!_canManage) return;
    await Navigator.pushNamed(context, AppRoutes.aiChallenge);
    if (mounted) await _load();
  }

  Future<void> _openDetail(Challenge challenge) async {
    final id = challenge.id;
    if (id == null) return;
    await Navigator.pushNamed(
      context,
      AppRoutes.challengeDetail,
      arguments: id,
    );
    if (mounted) await _load();
  }

  Future<void> _demoAction({required bool remove}) async {
    if (!_canUseDemoTools || _seeding) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
        title: Text(
          remove
              ? 'Supprimer les challenges de démo ?'
              : 'Générer les challenges de démo ?',
        ),
        content: Text(
          remove
              ? 'Vos challenges portant un titre de démo seront supprimés avec leurs tâches, inscriptions, progressions et notifications, même s’ils ont été créés manuellement.'
              : 'Vos challenges dont le titre existe déjà seront conservés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(remove ? 'Supprimer' : 'Générer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_canUseDemoTools || _seeding) return;
    setState(() => _seeding = true);
    try {
      final count = remove
          ? await ChallengeSeeder.instance.removeDemoChallenges()
          : await ChallengeSeeder.instance.seedDemoChallenges();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$count challenge(s) ${remove ? 'supprimé(s)' : 'ajouté(s)'}.',
          ),
        ),
      );
      await _load();
      if (remove) {
        try {
          await NotificationService.instance.refreshUnreadCount();
        } catch (e, s) {
          debugPrint('ERREUR ACTUALISATION NOTIFICATIONS : $e\n$s');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Suppression effectuée, mais impossible d’actualiser les notifications.',
                ),
              ),
            );
          }
        }
      }
    } catch (e, s) {
      debugPrint('ERREUR CHALLENGES DÉMO : $e\n$s');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Widget _developmentTools() => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: challengeCardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Outils de développement', style: AppTheme.sectionTitle),
        const SizedBox(height: 12),
        if (_seeding) const Center(child: AppLoader(size: 32)),
        if (!_seeding) ...[
          ElevatedButton(
            onPressed: () => _demoAction(remove: false),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.pillRadius),
              ),
            ),
            child: const Text(
              'Générer des challenges de démo',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _demoAction(remove: true),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.pillRadius),
              ),
            ),
            child: const Text(
              'Supprimer les challenges de démo',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    ),
  );

  Widget _card(Challenge c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: challengeCardDecoration(),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          onTap: () => _openDetail(c),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c.imagePath == null)
                      const ChallengeIconTile()
                    else
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(c.imagePath!),
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ChallengeIconTile(),
                        ),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        c.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    ChallengeStateChip(
                      state: c.timeState,
                      label: c.timeState.label,
                    ),
                    ChallengeChip(
                      label: c.difficulty.label,
                      icon: Icons.fitness_center,
                      color: AppTheme.primary,
                    ),
                    ChallengeChip(
                      label: '${c.xpReward} XP',
                      icon: Icons.bolt,
                      color: AppTheme.accent,
                    ),
                    if (_canManage) ChallengeStatusChip(status: c.status),
                    if (_myChallenges.any(
                      (item) =>
                          item.challenge.id == c.id &&
                          item.participation.status !=
                              ParticipantStatus.abandoned,
                    ))
                      const ChallengeChip(
                        label: 'Inscrit',
                        icon: Icons.check_circle_outline,
                        color: AppTheme.success,
                      ),
                  ],
                ),
                if (c.status == ChallengeStatus.rejected) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Consultez le motif du refus.',
                    style: TextStyle(color: AppTheme.error),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${formatChallengeDate(c.startDate)} → '
                        '${formatChallengeDate(c.endDate)}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.checklist,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${c.taskCount} tâche${c.taskCount > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.person_outline,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        c.creatorName ?? 'Inconnu',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scrollable(Widget child) {
    // Permet le pull-to-refresh même quand la liste est vide.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_canView) {
      return const Center(
        child: Text('Vous n\'avez pas accès aux challenges.'),
      );
    }
    if (_loading) {
      return const Center(child: AppLoader(size: 48));
    }
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: _scrollable(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }
    if (_memberTab == 2 && Permissions.currentCan(Permission.joinChallenge)) {
      return ChallengesCalendar(
        onDiscover: () => setState(() => _memberTab = 0),
        onDetailClosed: _load,
      );
    }
    if (_memberTab == 1 && Permissions.currentCan(Permission.joinChallenge)) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            if (_myChallenges.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Vous ne participez à aucun challenge.'),
                ),
              ),
            for (final item in _myChallenges)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: challengeCardDecoration(),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  onTap: () => _openDetail(item.challenge),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.challenge.title,
                          style: AppTheme.sectionTitle,
                        ),
                        const SizedBox(height: 8),
                        ChallengeChip(
                          label: item.participation.status.label,
                          icon: Icons.flag_outlined,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: item.participation.progressPercent / 100,
                          color: AppTheme.primary,
                          backgroundColor: AppTheme.lavender,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${item.participation.progressPercent.round()} % · '
                          '${item.challenge.currentDayNumber == null ? 'À venir' : 'Jour ${item.challenge.currentDayNumber}/${item.challenge.totalDays}'}',
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    if (_challenges.isEmpty) {
      if (_canUseDemoTools) {
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 90),
            children: [
              const Center(child: ChallengeIconTile(size: 88)),
              const SizedBox(height: 12),
              const Text(
                'Aucun challenge pour le moment',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Appuyez sur + pour créer le premier.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              _developmentTools(),
            ],
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: _load,
        child: _scrollable(
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ChallengeIconTile(size: 88),
                const SizedBox(height: 12),
                const Text(
                  'Aucun challenge pour le moment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _canManage
                      ? 'Appuyez sur + pour créer le premier.'
                      : 'Revenez bientôt !',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        itemCount: _challenges.length + (_canUseDemoTools ? 1 : 0),
        itemBuilder: (_, i) => i == _challenges.length
            ? _developmentTools()
            : _card(_challenges[i]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          GradientHeader(
            title: 'Challenges',
            subtitle:
                '${_challenges.where((c) => c.status == ChallengeStatus.active).length} challenges actifs',
          ),
          if (Permissions.currentCan(Permission.joinChallenge))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.lavender,
                  borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                ),
                child: Row(
                  children: [
                    for (final (index, item) in [
                      (Icons.explore_outlined, 'Découvrir'),
                      (Icons.flag_outlined, 'Mes défis'),
                      (Icons.calendar_month, 'Calendrier'),
                    ].indexed)
                      Expanded(
                        child: Material(
                          color: _memberTab == index
                              ? AppTheme.primary
                              : AppTheme.lavender.withValues(alpha: 0),
                          borderRadius: BorderRadius.circular(
                            AppTheme.pillRadius,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              AppTheme.pillRadius,
                            ),
                            onTap: () => setState(() => _memberTab = index),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    item.$1,
                                    size: 15,
                                    color: _memberTab == index
                                        ? AppTheme.surface
                                        : AppTheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      item.$2,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _memberTab == index
                                            ? AppTheme.surface
                                            : AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (_canManage)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: OutlinedButton.icon(
                onPressed: _openAiGenerator,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  backgroundColor: AppTheme.surface,
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Génération automatique'),
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: _openForm,
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.surface,
              shape: const StadiumBorder(),
              icon: const Icon(Icons.add),
              label: const Text('Nouveau'),
            )
          : null,
    );
  }
}
