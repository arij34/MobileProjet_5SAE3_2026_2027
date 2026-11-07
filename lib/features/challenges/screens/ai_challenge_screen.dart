import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/session/permissions.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/pill_decoration.dart';
import '../models/challenge.dart';
import '../models/challenge_difficulty.dart';
import '../services/ai_challenge_generator.dart';
import '../widgets/challenge_styles.dart';

class AiChallengeDraft {
  const AiChallengeDraft(this.challenge);
  final Challenge challenge;
}

class AiChallengeScreen extends StatefulWidget {
  const AiChallengeScreen({super.key, this.generator});

  final AiChallengeGenerator? generator;

  @override
  State<AiChallengeScreen> createState() => _AiChallengeScreenState();
}

class _AiChallengeScreenState extends State<AiChallengeScreen> {
  final _instructions = TextEditingController();
  final _focus = <AiFocusArea>{};
  ChallengeDifficulty _difficulty = ChallengeDifficulty.medium;
  int _duration = 14;
  int _count = 5;
  bool _loading = false;

  @override
  void dispose() {
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_loading) return;
    final user = SessionManager.instance.currentUser;
    if (user == null ||
        user.id == null ||
        !Permissions.can(user, Permission.manageChallenges)) {
      _showError('Vous n’avez pas le droit de créer un challenge.');
      return;
    }
    if (_focus.isEmpty) {
      _showError('Choisissez au moins un type de tâche.');
      return;
    }
    setState(() => _loading = true);
    try {
      final draft = await (widget.generator ?? AiChallengeGenerator.instance)
          .generateChallenge(AiChallengeRequest(
            difficulty: _difficulty,
            durationDays: _duration,
            taskCount: _count,
            focusAreas: _focus.toList(),
            extraInstructions: _instructions.text,
          ));
      if (!mounted) return;
      final current = SessionManager.instance.currentUser;
      if (current == null ||
          current.id != user.id ||
          !Permissions.can(current, Permission.manageChallenges)) {
        _showError('La session a changé. Reconnectez-vous.');
        return;
      }
      final created = await Navigator.pushNamed(
        context,
        AppRoutes.challengeForm,
        arguments: AiChallengeDraft(draft),
      );
      if (mounted && created == true) Navigator.pop(context, true);
    } on AiChallengeException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final allowed = Permissions.currentCan(Permission.manageChallenges);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          const GradientHeader(title: 'Générer avec l’IA'),
          Expanded(
            child: !allowed
                ? const Center(
                    child: Text('Vous n’avez pas accès à cette fonctionnalité.'),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: challengeCardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Difficulté', style: AppTheme.sectionTitle),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final difficulty in ChallengeDifficulty.values)
                                  ChoiceChip(
                                    label: Text(difficulty.label),
                                    selected: _difficulty == difficulty,
                                    selectedColor: AppTheme.lavender,
                                    onSelected: _loading
                                        ? null
                                        : (_) => setState(() => _difficulty = difficulty),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text('Durée : $_duration jours', style: AppTheme.sectionTitle),
                            Slider(
                              value: _duration.toDouble(),
                              min: 3,
                              max: 90,
                              divisions: 87,
                              label: '$_duration jours',
                              onChanged: _loading
                                  ? null
                                  : (value) => setState(() => _duration = value.round()),
                            ),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text('Nombre de tâches', style: AppTheme.sectionTitle),
                                ),
                                IconButton(
                                  tooltip: 'Moins de tâches',
                                  onPressed: _loading || _count <= 2
                                      ? null
                                      : () => setState(() => _count--),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text('$_count'),
                                IconButton(
                                  tooltip: 'Plus de tâches',
                                  onPressed: _loading || _count >= 12
                                      ? null
                                      : () => setState(() => _count++),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text('Types de tâches', style: AppTheme.sectionTitle),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (final focus in AiFocusArea.values)
                                  FilterChip(
                                    label: Text(focus.label),
                                    selected: _focus.contains(focus),
                                    selectedColor: AppTheme.lavender,
                                    onSelected: _loading
                                        ? null
                                        : (selected) => setState(() {
                                            if (selected) {
                                              _focus.add(focus);
                                            } else {
                                              _focus.remove(focus);
                                            }
                                          }),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _instructions,
                              enabled: !_loading,
                              maxLength: 200,
                              maxLines: 3,
                              decoration: pillDecoration('Instructions supplémentaires'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: allowed
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _generate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.surface,
                    shape: const StadiumBorder(),
                  ),
                  icon: _loading
                      ? const AppLoader(size: 20)
                      : const Icon(Icons.auto_awesome),
                  label: Text(_loading ? 'Génération en cours...' : 'Générer'),
                ),
              ),
            )
          : null,
    );
  }
}
