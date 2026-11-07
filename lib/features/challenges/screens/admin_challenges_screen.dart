import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/session/permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/gradient_header.dart';
import '../models/challenge.dart';
import '../models/challenge_status.dart';
import '../services/challenge_service.dart';
import '../widgets/challenge_styles.dart';

class AdminChallengesScreen extends StatefulWidget {
  const AdminChallengesScreen({super.key, this.service});

  final ChallengeService? service;

  @override
  State<AdminChallengesScreen> createState() => _AdminChallengesScreenState();
}

class _AdminChallengesScreenState extends State<AdminChallengesScreen> {
  static const _statuses = [
    ChallengeStatus.pending,
    ChallengeStatus.active,
    ChallengeStatus.rejected,
    ChallengeStatus.cancelled,
  ];
  List<Challenge> _challenges = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Permissions.currentCan(Permission.reviewChallenges)) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final challenges = await (widget.service ?? ChallengeService.instance)
          .getChallenges();
      if (!mounted) return;
      setState(() {
        _challenges = challenges;
        _error = null;
        _loading = false;
      });
    } catch (e, s) {
      debugPrint('ERREUR CHALLENGES ADMIN : $e\n$s');
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les challenges';
        _loading = false;
      });
    }
  }

  Widget _list(ChallengeStatus status) {
    final items = _challenges
        .where(
          (c) =>
              c.status == status &&
              c.title.toLowerCase().contains(_search.toLowerCase().trim()),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Aucun challenge dans cette catégorie.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          for (final challenge in items)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: challengeCardDecoration(),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  onTap: () async {
                    await Navigator.pushNamed(
                      context,
                      AppRoutes.challengeDetail,
                      arguments: challenge.id,
                    );
                    if (mounted) await _load();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(challenge.title, style: AppTheme.sectionTitle),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChallengeStatusChip(status: challenge.status),
                            ChallengeChip(
                              label: challenge.difficulty.label,
                              icon: Icons.fitness_center,
                              color: AppTheme.primary,
                            ),
                            ChallengeChip(
                              label: '${challenge.xpReward} XP',
                              icon: Icons.bolt,
                              color: AppTheme.accent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('Coach : ${challenge.creatorName ?? 'Inconnu'}'),
                        Text(
                          '${formatChallengeDate(challenge.startDate)} → ${formatChallengeDate(challenge.endDate)}',
                        ),
                        Text(
                          '${challenge.taskCount} tâche(s) · Soumis le ${formatChallengeDate(challenge.createdAt)}',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Permissions.currentCan(Permission.reviewChallenges)) {
      return const Scaffold(
        body: Center(child: Text('Accès réservé à l’administrateur.')),
      );
    }
    return DefaultTabController(
      length: _statuses.length,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Column(
          children: [
            const GradientHeader(title: 'Challenges'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: TextField(
                onChanged: (value) => setState(() => _search = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Rechercher par titre',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                  ),
                ),
              ),
            ),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              labelPadding: EdgeInsets.symmetric(horizontal: 12),
              tabs: [
                Tab(text: 'En attente'),
                Tab(text: 'Approuvés'),
                Tab(text: 'Rejetés'),
                Tab(text: 'Annulés'),
              ],
            ),
            Expanded(
              child: _loading
                  ? const Center(child: AppLoader(size: 48))
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!),
                          TextButton(
                            onPressed: _load,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    )
                  : SafeArea(
                      top: false,
                      child: TabBarView(
                        children: [for (final status in _statuses) _list(status)],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
