import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/session/permissions.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/gradient_header.dart';
import '../models/challenge.dart';
import '../models/challenge_status.dart';
import '../models/challenge_task.dart';
import '../models/challenge_participant.dart';
import '../models/challenge_task_progress.dart';
import '../models/day_plan.dart';
import '../models/participant_status.dart';
import '../models/challenge_type.dart';
import '../services/challenge_service.dart';
import '../services/participation_service.dart';
import '../widgets/challenge_styles.dart';
import '../widgets/day_task_check_button.dart';

enum _ChallengeAction { edit, cancel, delete, leave }

class ChallengeDetailScreen extends StatefulWidget {
  final int challengeId;

  const ChallengeDetailScreen({super.key, required this.challengeId});

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

String _stateLabel(ChallengeTimeState state) =>
    state == ChallengeTimeState.ended ? 'Terminée' : state.label;

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  Challenge? _challenge;
  bool _loading = true;
  bool _reviewing = false;
  bool _participationBusy = false;
  ChallengeParticipant? _participation;
  List<DayPlan> _days = const [];
  int? _selectedDay;
  bool _byDay = true;
  ScrollController _dayScroll = ScrollController();
  String? _error;

  bool get _canModify {
    final challenge = _challenge;
    return challenge != null &&
        Permissions.currentCanModifyChallenge(challenge.createdBy);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final member = Permissions.currentCan(Permission.joinChallenge);
      final participation = member
          ? await ParticipationService.instance.getMyParticipation(
              widget.challengeId,
            )
          : null;
      final challenge = member && participation != null
          ? await ParticipationService.instance.getMyChallenge(
              widget.challengeId,
            )
          : await ChallengeService.instance.getChallengeById(
              widget.challengeId,
            );
      final days = member && participation != null
          ? await ParticipationService.instance.getDayPlan(widget.challengeId)
          : <DayPlan>[];
      if (!mounted) return;
      if (days.isNotEmpty && _selectedDay == null) {
        _selectedDay = challenge?.currentDayNumber ?? 1;
        _dayScroll.dispose();
        _dayScroll = ScrollController(
          initialScrollOffset: (_selectedDay! - 1) * 116.0,
        );
      }
      setState(() {
        _challenge = challenge;
        _participation = participation;
        _days = days;
        _error = challenge == null ? 'Challenge introuvable' : null;
        _loading = false;
      });
      if (days.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _dayScroll.hasClients) {
            _dayScroll.jumpTo(
              ((_selectedDay! - 1) * 116.0).clamp(
                0,
                _dayScroll.position.maxScrollExtent,
              ),
            );
          }
        });
      }
    } catch (e, s) {
      debugPrint('ERREUR DÉTAIL CHALLENGE : $e\n$s');
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger ce challenge';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _dayScroll.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Retour'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: destructive
                    ? TextButton.styleFrom(foregroundColor: AppTheme.error)
                    : null,
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _handleAction(_ChallengeAction action) async {
    final challenge = _challenge;
    if (challenge == null) return;
    if (action == _ChallengeAction.leave) {
      await _leave();
      return;
    }
    if (!_canModify) return;

    switch (action) {
      case _ChallengeAction.edit:
        if (ChallengeService.coachEditLocked(
          SessionManager.instance.currentUser,
          challenge,
          DateTime.now(),
        )) {
          _snack(
            'Un coach ne peut plus modifier un challenge dès sa date de début',
          );
          return;
        }
        final saved = await Navigator.pushNamed(
          context,
          AppRoutes.challengeForm,
          arguments: challenge.id,
        );
        if (saved == true) {
          await _load();
        }
        break;
      case _ChallengeAction.cancel:
        final confirmed = await _confirm(
          title: 'Annuler le challenge ?',
          message: 'Les inscriptions et la progression seront conservées.',
          action: 'Annuler le challenge',
          destructive: true,
        );
        if (!confirmed) return;
        try {
          await ChallengeService.instance.cancelChallenge(widget.challengeId);
          _snack('Challenge annulé');
          await _load();
        } on ChallengeException catch (e) {
          _snack(e.message);
        } catch (e, s) {
          debugPrint('ERREUR ANNULATION CHALLENGE : $e\n$s');
          _snack('Impossible d\'annuler le challenge : $e');
        }
        break;
      case _ChallengeAction.delete:
        final confirmed = await _confirm(
          title: 'Supprimer le challenge ?',
          message: 'Cette action est définitive.',
          action: 'Supprimer',
          destructive: true,
        );
        if (!confirmed) return;
        try {
          await ChallengeService.instance.deleteChallenge(widget.challengeId);
          _snack('Challenge supprimé');
          if (mounted) Navigator.pop(context, true);
        } on ChallengeException catch (e) {
          _snack(e.message);
        } catch (e, s) {
          debugPrint('ERREUR SUPPRESSION CHALLENGE : $e\n$s');
          _snack('Impossible de supprimer le challenge : $e');
        }
        break;
      case _ChallengeAction.leave:
        break;
    }
  }

  Future<void> _join() async {
    if (_participationBusy) return;
    final resume = _participation?.status == ParticipantStatus.abandoned;
    if (!await _confirm(
          title: resume
              ? 'Reprendre ce challenge ?'
              : 'Rejoindre ce challenge ?',
          message: resume
              ? 'Votre progression sera conservée.'
              : 'Vous pourrez suivre votre progression personnelle.',
          action: resume ? 'Reprendre' : 'Rejoindre',
        ) ||
        !mounted) {
      return;
    }
    setState(() => _participationBusy = true);
    try {
      await ParticipationService.instance.joinChallenge(widget.challengeId);
      _snack(resume ? 'Challenge repris' : 'Challenge rejoint');
      await _load();
    } on ChallengeException catch (e) {
      _snack(e.message);
    } catch (e, s) {
      debugPrint('ERREUR INSCRIPTION CHALLENGE : $e\n$s');
      _snack('Impossible de rejoindre ce challenge.');
    } finally {
      if (mounted) setState(() => _participationBusy = false);
    }
  }

  Future<void> _leave() async {
    if (_participationBusy) return;
    if (!await _confirm(
          title: 'Quitter le challenge ?',
          message:
              'Votre progression sera conservée si vous reprenez le challenge.',
          action: 'Quitter',
          destructive: true,
        ) ||
        !mounted) {
      return;
    }
    setState(() => _participationBusy = true);
    try {
      await ParticipationService.instance.leaveChallenge(widget.challengeId);
      _snack('Challenge quitté');
      await _load();
    } on ChallengeException catch (e) {
      _snack(e.message);
    } catch (e, s) {
      debugPrint('ERREUR DÉSINSCRIPTION CHALLENGE : $e\n$s');
      _snack('Impossible de quitter ce challenge.');
    } finally {
      if (mounted) setState(() => _participationBusy = false);
    }
  }

  Future<void> _addProgress(
    ChallengeTask task,
    ChallengeTaskProgress progress,
    DateTime day,
  ) async {
    if (_participationBusy || task.id == null) return;
    final remaining = task.targetValue - progress.progress;
    final controller = TextEditingController();
    final form = GlobalKey<FormState>();
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ajouter une progression · ${formatChallengeDate(day)}'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Restant : ${_number(remaining)} ${task.unit.label}',
            ),
            validator: (value) {
              final n = double.tryParse(
                (value ?? '').trim().replaceAll(',', '.'),
              );
              if (n == null || !n.isFinite || n <= 0) {
                return 'Entrez une valeur supérieure à 0';
              }
              if (n > remaining) return 'La valeur dépasse le restant';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(
                  context,
                  double.parse(controller.text.trim().replaceAll(',', '.')),
                );
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || !mounted) return;
    await _recordProgress(task, day, amount);
  }

  Future<void> _checkDailyTask(
    DayPlan day,
    DayTaskStatus item,
    ChallengeTaskProgress progress,
  ) async {
    if (_participationBusy) return;
    final amount = item.remainingToCheck(progress.progress);
    if (amount <= 0) return;
    final confirmed = await _confirm(
      title: 'Terminer cette tâche ?',
      message:
          'Ajouter ${_number(amount)} ${item.task.unit.label} pour '
          'le ${formatChallengeDate(day.date)} ? '
          'La progression ne peut pas être retirée.',
      action: 'Confirmer',
    );
    if (!confirmed || !mounted) return;
    await _recordProgress(item.task, day.date, amount);
  }

  Future<void> _recordProgress(
    ChallengeTask task,
    DateTime day,
    double amount,
  ) async {
    if (_participationBusy || task.id == null) return;
    setState(() => _participationBusy = true);
    try {
      final completed = await ParticipationService.instance.logProgress(
        task.id!,
        day,
        amount,
      );
      await _load();
      if (completed && mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Challenge terminé !'),
            content: Text('+${_challenge?.xpReward ?? 0} XP'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Super !'),
              ),
            ],
          ),
        );
      } else {
        _snack('Progression enregistrée');
      }
    } on ChallengeException catch (e) {
      _snack(e.message);
    } catch (e, s) {
      debugPrint('ERREUR PROGRESSION CHALLENGE : $e\n$s');
      _snack('Impossible d’enregistrer la progression.');
    } finally {
      if (mounted) setState(() => _participationBusy = false);
    }
  }

  String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  Future<void> _review({required bool approve}) async {
    if (_reviewing || !Permissions.currentCan(Permission.reviewChallenges)) {
      return;
    }
    String? reason;
    if (approve) {
      if (!await _confirm(
        title: 'Approuver ce challenge ?',
        message: 'Il sera visible par les membres.',
        action: 'Approuver',
      )) {
        return;
      }
    } else {
      final controller = TextEditingController();
      final formKey = GlobalKey<FormState>();
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          title: const Text('Motif du refus'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Motif'),
              validator: (value) => (value ?? '').trim().length < 5
                  ? 'Au moins 5 caractères requis'
                  : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Retour'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, controller.text.trim());
                }
              },
              child: const Text(
                'Rejeter',
                style: TextStyle(color: AppTheme.error),
              ),
            ),
          ],
        ),
      );
      controller.dispose();
      if (reason == null) return;
    }
    if (!mounted) return;
    setState(() => _reviewing = true);
    try {
      if (approve) {
        await ChallengeService.instance.approveChallenge(widget.challengeId);
      } else {
        await ChallengeService.instance.rejectChallenge(
          widget.challengeId,
          reason!,
        );
      }
      _snack(approve ? 'Challenge approuvé' : 'Challenge rejeté');
      await _load();
    } on ChallengeException catch (e) {
      _snack(e.message);
    } catch (e, s) {
      debugPrint('ERREUR ÉVALUATION CHALLENGE : $e\n$s');
      _snack('Impossible d\'évaluer le challenge : $e');
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  Widget _taskCard(ChallengeTask task, int index) {
    final matches = _participation?.tasks.where((p) => p.taskId == task.id);
    final progress = matches == null || matches.isEmpty ? null : matches.first;
    final target = task.targetValue.toString();
    final displayTarget = target.endsWith('.0')
        ? target.substring(0, target.length - 2)
        : target;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: challengeCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.accent.withValues(alpha: 0.12),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        switch (task.type) {
                          ChallengeType.workout => Icons.fitness_center,
                          ChallengeType.running => Icons.directions_run,
                          ChallengeType.steps => Icons.directions_walk,
                          ChallengeType.nutrition => Icons.restaurant_outlined,
                          ChallengeType.flexibility => Icons.self_improvement,
                          ChallengeType.custom => Icons.checklist,
                        },
                        size: 15,
                        color: AppTheme.accent,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${task.type.label} · $displayTarget ${task.unit.label}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (task.description?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(
                      task.description!,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                  if (progress != null) ...[
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: (progress.progress / task.targetValue).clamp(0, 1),
                      color: AppTheme.primary,
                      backgroundColor: AppTheme.lavender,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_number(progress.progress)} / $displayTarget ${task.unit.label}',
                    ),
                    if (progress.completed)
                      const Text(
                        'Terminée ✓',
                        style: TextStyle(color: AppTheme.success),
                      )
                    else if (_participation?.status ==
                            ParticipantStatus.joined &&
                        _challenge?.status == ChallengeStatus.active &&
                        _challenge!.timeState == ChallengeTimeState.ongoing &&
                        task.isScheduledOn(DateTime.now()))
                      OutlinedButton(
                        onPressed: _participationBusy
                            ? null
                            : () =>
                                  _addProgress(task, progress, DateTime.now()),
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                        ),
                        child: const Text('Ajouter'),
                      ),
                    if (!progress.completed &&
                        _participation?.status == ParticipantStatus.joined &&
                        !task.isScheduledOn(DateTime.now()))
                      const Text('Tâche non prévue aujourd’hui'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(Challenge challenge) {
    final state = challenge.timeState;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      children: [
        if (_participation != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: challengeCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ma progression : ${_participation!.progressPercent.round()} %',
                  style: AppTheme.sectionTitle,
                ),
                if (challenge.timeState == ChallengeTimeState.ended &&
                    _participation!.status == ParticipantStatus.joined)
                  const Text(
                    'Challenge terminé : la progression est verrouillée.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _participation!.progressPercent / 100,
                  color: AppTheme.primary,
                  backgroundColor: AppTheme.lavender,
                ),
                const SizedBox(height: 8),
                Text(
                  '${_participation!.tasks.where((t) => t.completed).length}/${_participation!.tasks.length} tâches terminées · ${mathDaysLeft(challenge.endDate)} jours restants',
                ),
                Text(
                  challenge.currentDayNumber == null
                      ? 'Pas encore commencé · ${challenge.totalDays} jours'
                      : 'Jour ${challenge.currentDayNumber} sur ${challenge.totalDays}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_days.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Par jour'),
                  selected: _byDay,
                  onSelected: (_) => setState(() => _byDay = true),
                ),
                ChoiceChip(
                  label: const Text('Par tâche'),
                  selected: !_byDay,
                  onSelected: (_) => setState(() => _byDay = false),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_byDay)
              ..._dayView()
            else
              for (var i = 0; i < challenge.tasks.length; i++)
                _taskCard(challenge.tasks[i], i),
            const SizedBox(height: 18),
          ],
        ],
        if (challenge.imagePath != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: Image.file(
              File(challenge.imagePath!),
              height: 210,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _coverBanner(),
            ),
          )
        else
          _coverBanner(),
        const SizedBox(height: 18),
        Text(
          challenge.title,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChallengeStateChip(state: state, label: _stateLabel(state)),
            if (Permissions.currentCan(Permission.manageChallenges) ||
                Permissions.currentCan(Permission.reviewChallenges))
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
        if (challenge.status == ChallengeStatus.pending &&
            SessionManager.instance.currentUser?.id == challenge.createdBy) ...[
          const SizedBox(height: 16),
          _statusCard('En attente de validation par l’administrateur'),
        ],
        if (challenge.status == ChallengeStatus.rejected &&
            (Permissions.currentCan(Permission.reviewChallenges) ||
                SessionManager.instance.currentUser?.id ==
                    challenge.createdBy)) ...[
          const SizedBox(height: 16),
          _statusCard(
            'Motif du refus : ${challenge.rejectionReason ?? 'Non renseigné'}'
            '\nÉvalué par ${challenge.reviewerName ?? 'Inconnu'}'
            '${challenge.reviewedAt == null ? '' : ' le ${formatChallengeDate(challenge.reviewedAt!)}'}',
          ),
          if (SessionManager.instance.currentUser?.id == challenge.createdBy &&
              !Permissions.currentCan(Permission.reviewChallenges)) ...[
            const SizedBox(height: 12),
            CustomButton(
              text: 'Modifier et soumettre à nouveau',
              onPressed: () => _handleAction(_ChallengeAction.edit),
            ),
          ],
        ],
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: challengeCardDecoration(),
          child: Column(
            children: [
              _infoRow(
                Icons.calendar_today_outlined,
                '${formatChallengeDate(challenge.startDate)} → '
                '${formatChallengeDate(challenge.endDate)}',
              ),
              const SizedBox(height: 10),
              _infoRow(
                Icons.person_outline,
                challenge.creatorName ?? 'Inconnu',
              ),
              const SizedBox(height: 10),
              _infoRow(Icons.bolt, '${challenge.xpReward} XP'),
            ],
          ),
        ),
        if (challenge.description.trim().isNotEmpty) ...[
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: challengeCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  challenge.description,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (_participation == null || _days.isEmpty) ...[
          Text(
            'Tâches (${challenge.tasks.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < challenge.tasks.length; i++)
            _taskCard(challenge.tasks[i], i),
        ],
      ],
    );
  }

  List<Widget> _dayView() {
    final selected = (_selectedDay ?? 1).clamp(1, _days.length);
    final day = _days[selected - 1];
    Color color(DayState state) => switch (state) {
      DayState.done => AppTheme.success,
      DayState.partial => AppTheme.accent,
      DayState.missed => AppTheme.error,
      DayState.nothing => AppTheme.textSecondary,
    };
    final groups = [
      (
        'À faire',
        day.tasks.where(
          (t) => t.state == DayTaskState.todo || t.state == DayTaskState.missed,
        ),
      ),
      ('En cours', day.tasks.where((t) => t.state == DayTaskState.inProgress)),
      ('Terminé', day.tasks.where((t) => t.state == DayTaskState.done)),
    ];
    return [
      SizedBox(
        height: 52,
        child: ListView.builder(
          controller: _dayScroll,
          scrollDirection: Axis.horizontal,
          itemExtent: 116,
          itemCount: _days.length,
          itemBuilder: (context, index) {
            final item = _days[index];
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                selected: selected == item.dayNumber,
                side: item.isToday
                    ? const BorderSide(color: AppTheme.primary, width: 2)
                    : null,
                label: Text(
                  'Jour ${item.dayNumber}${item.isToday ? ' · *' : ''}',
                ),
                avatar: Icon(Icons.circle, size: 10, color: color(item.state)),
                onSelected: (_) =>
                    setState(() => _selectedDay = item.dayNumber),
              ),
            );
          },
        ),
      ),
      const Text(
        '* Aujourd’hui',
        style: TextStyle(color: AppTheme.textSecondary),
      ),
      Text(formatChallengeDate(day.date), style: AppTheme.sectionTitle),
      if (day.tasks.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Aucune tâche prévue pour cette journée.'),
        ),
      if (day.tasks.any((t) => t.isEstimated))
        const Text(
          'Les anciennes progressions de cette journée ont une date estimée.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      for (final group in groups)
        if (group.$2.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(group.$1, style: AppTheme.sectionTitle),
          for (final item in group.$2) _dayTaskCard(day, item),
        ],
    ];
  }

  Widget _dayTaskCard(DayPlan day, DayTaskStatus item) {
    final progress = _participation!.tasks.firstWhere(
      (p) => p.taskId == item.task.id,
    );
    final canAdd =
        !day.isFuture &&
        !item.objectiveReached &&
        item.dailyQuota > 0 &&
        !progress.completed &&
        _participation!.status == ParticipantStatus.joined &&
        _challenge!.status == ChallengeStatus.active &&
        _challenge!.timeState == ChallengeTimeState.ongoing;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: challengeCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DayTaskCheckButton(
            state: item.state,
            onPressed:
                canAdd && item.state != DayTaskState.done && !_participationBusy
                ? () => _checkDailyTask(day, item, progress)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.task.title, style: AppTheme.sectionTitle),
                Text(
                  item.dailyQuota <= 0
                      ? 'Aucune tâche prévue'
                      : item.objectiveReached
                      ? 'Objectif atteint'
                      : '${_number(item.loggedAmount)} / ${_number(item.dailyQuota)} ${item.task.unit.label}',
                ),
                if (item.state == DayTaskState.missed)
                  const Text('Manqué', style: TextStyle(color: AppTheme.error)),
                if (day.isFuture &&
                    !item.objectiveReached &&
                    item.dailyQuota > 0)
                  Text('Disponible le ${formatChallengeDate(day.date)}'),
                if (canAdd)
                  OutlinedButton(
                    onPressed: _participationBusy
                        ? null
                        : () => _addProgress(item.task, progress, day.date),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Ajouter'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int mathDaysLeft(DateTime end) {
    final today = DateTime.now();
    final days = DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    return days < 0 ? 0 : days;
  }

  Widget _statusCard(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.accent.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
    ),
    child: Text(text, style: const TextStyle(color: AppTheme.textPrimary)),
  );

  Widget _coverBanner() => Container(
    height: 160,
    decoration: BoxDecoration(
      gradient: AppTheme.challengeGradient,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
    ),
    child: const Center(
      child: Icon(Icons.emoji_events, size: 72, color: AppTheme.surface),
    ),
  );

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: AppTheme.accent),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }

  List<PopupMenuEntry<_ChallengeAction>> _menuItems(Challenge challenge) => [
    if (challenge.status != ChallengeStatus.cancelled &&
        !ChallengeService.coachEditLocked(
          SessionManager.instance.currentUser,
          challenge,
          DateTime.now(),
        ))
      const PopupMenuItem(
        value: _ChallengeAction.edit,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.edit_outlined),
          title: Text('Modifier'),
        ),
      ),
    if (challenge.status != ChallengeStatus.cancelled)
      const PopupMenuItem(
        value: _ChallengeAction.cancel,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.cancel_outlined),
          title: Text('Annuler le challenge'),
        ),
      ),
    const PopupMenuItem(
      value: _ChallengeAction.delete,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.delete_outline, color: AppTheme.error),
        title: Text('Supprimer', style: TextStyle(color: AppTheme.error)),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final challenge = _challenge;
    final member = Permissions.currentCan(Permission.joinChallenge);
    final canJoin =
        challenge != null &&
        challenge.status == ChallengeStatus.active &&
        challenge.timeState != ChallengeTimeState.ended;
    final showJoin =
        member &&
        challenge != null &&
        (_participation == null ||
            _participation!.status == ParticipantStatus.abandoned);
    return Scaffold(
      backgroundColor: AppTheme.background,
      bottomNavigationBar:
          !_loading &&
              _error == null &&
              challenge?.status == ChallengeStatus.pending &&
              Permissions.currentCan(Permission.reviewChallenges)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Approuver',
                        isLoading: _reviewing,
                        onPressed: () => _review(approve: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _reviewing
                            ? null
                            : () => _review(approve: false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: const BorderSide(color: AppTheme.error),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.pillRadius,
                            ),
                          ),
                        ),
                        child: const Text('Rejeter'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : !_loading && _error == null && showJoin
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!canJoin)
                      Text(
                        challenge.status == ChallengeStatus.cancelled
                            ? 'Ce challenge est annulé'
                            : 'Ce challenge est terminé',
                      ),
                    ElevatedButton(
                      onPressed: canJoin && !_participationBusy ? _join : null,
                      style: ElevatedButton.styleFrom(
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        _participation?.status == ParticipantStatus.abandoned
                            ? 'Reprendre le challenge'
                            : 'Rejoindre le challenge',
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: Column(
        children: [
          GradientHeader(
            title: 'Détail du challenge',
            action: member && _participation?.status == ParticipantStatus.joined
                ? PopupMenuButton<_ChallengeAction>(
                    iconColor: AppTheme.surface,
                    onSelected: _handleAction,
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _ChallengeAction.leave,
                        child: Text('Quitter le challenge'),
                      ),
                    ],
                  )
                : _canModify && challenge != null
                ? PopupMenuButton<_ChallengeAction>(
                    iconColor: AppTheme.surface,
                    color: AppTheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    ),
                    onSelected: _handleAction,
                    itemBuilder: (_) => _menuItems(challenge),
                  )
                : null,
          ),
          Expanded(
            child: !Permissions.currentCan(Permission.viewChallenges)
                ? const Center(
                    child: Text('Vous n\'avez pas accès aux challenges.'),
                  )
                : _loading
                ? const Center(child: AppLoader(size: 48))
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  )
                : challenge == null
                ? const Center(child: Text('Challenge introuvable'))
                : _buildContent(challenge),
          ),
        ],
      ),
    );
  }
}
