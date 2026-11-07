import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/session/permissions.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/pill_decoration.dart';
import '../models/challenge.dart';
import '../models/challenge_difficulty.dart';
import '../models/challenge_status.dart';
import '../models/challenge_task.dart';
import '../models/challenge_task_log.dart';
import '../models/challenge_type.dart';
import '../models/challenge_unit.dart';
import '../services/challenge_service.dart';
import '../widgets/challenge_styles.dart';
import 'ai_challenge_screen.dart';
import '../../users/models/user_role.dart';

/// Ligne de tâche en cours de saisie (avec ses propres champs de texte).
class _TaskDraft {
  _TaskDraft({ChallengeTask? task}) {
    if (task == null) return;
    id = task.id;
    challengeId = task.challengeId;
    title.text = task.title;
    description.text = task.description ?? '';
    target.text = task.targetValue.toString();
    type = task.type;
    unit = task.unit;
    xpReward = task.xpReward;
    scheduledDates = [...task.scheduledDates];
  }

  final Key key = UniqueKey();
  final TextEditingController title = TextEditingController();
  final TextEditingController description = TextEditingController();
  final TextEditingController target = TextEditingController();
  int? id;
  int challengeId = 0;
  int xpReward = 0;
  ChallengeType type = ChallengeType.workout;
  ChallengeUnit unit = ChallengeUnit.reps;
  List<DateTime> scheduledDates = [];

  void dispose() {
    title.dispose();
    description.dispose();
    target.dispose();
  }

  ChallengeTask toTask() {
    final desc = description.text.trim();
    return ChallengeTask(
      id: id,
      challengeId: challengeId,
      title: title.text.trim(),
      description: desc.isEmpty ? null : desc,
      type: type,
      unit: unit,
      targetValue: parseTarget(target.text) ?? 0,
      xpReward: xpReward,
      scheduledDates: [...scheduledDates],
    );
  }

  static double? parseTarget(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));
}

class ChallengeFormScreen extends StatefulWidget {
  const ChallengeFormScreen({super.key, this.service});

  @visibleForTesting
  final ChallengeService? service;

  @override
  State<ChallengeFormScreen> createState() => _ChallengeFormScreenState();
}

class _ChallengeFormScreenState extends State<ChallengeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _xpController = TextEditingController(
    text: ChallengeDifficulty.medium.defaultXp.toString(),
  );
  final List<_TaskDraft> _tasks = [_TaskDraft()];

  ChallengeDifficulty _difficulty = ChallengeDifficulty.medium;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _imagePath;
  String? _initialImagePath;
  Challenge? _existingChallenge;
  int? _challengeId;
  int _participantCount = 0;
  bool _xpEdited = false;
  bool _loading = false;
  bool _initializing = true;
  bool _loadError = false;
  bool _routeRead = false;
  bool _generatedByAi = false;

  bool get _isEditMode => _challengeId != null || _existingChallenge != null;
  bool get _taskEditingLocked => _isEditMode && _participantCount > 0;
  ChallengeService get _service => widget.service ?? ChallengeService.instance;
  bool get _coachEditLocked =>
      _existingChallenge != null &&
      ChallengeService.coachEditLocked(
        SessionManager.instance.currentUser,
        _existingChallenge!,
        DateTime.now(),
      );
  bool get _canEdit {
    final existing = _existingChallenge;
    if (_isEditMode) {
      return existing != null &&
          existing.status != ChallengeStatus.cancelled &&
          Permissions.currentCanModifyChallenge(existing.createdBy) &&
          !_coachEditLocked;
    }
    return Permissions.currentCan(Permission.manageChallenges);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _xpController.dispose();
    for (final t in _tasks) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeRead) return;
    _routeRead = true;
    final argument = ModalRoute.of(context)?.settings.arguments;
    if (argument is AiChallengeDraft) {
      _populate(argument.challenge);
      _generatedByAi = true;
      _initializing = false;
    } else if (argument is int) {
      _challengeId = argument;
      _loadExisting();
    } else if (argument is Challenge) {
      _challengeId = argument.id;
      if (_challengeId != null) {
        _loadExisting();
      } else {
        _existingChallenge = argument;
        _populate(argument);
        _initializing = false;
      }
    } else {
      _initializing = false;
    }
  }

  Future<void> _loadExisting() async {
    final id = _challengeId;
    if (id == null) return;
    try {
      final challenge = await _service.getChallengeById(id);
      if (challenge == null) {
        if (mounted) {
          setState(() {
            _loadError = true;
            _initializing = false;
          });
        }
        return;
      }
      final participantCount = await _service.countParticipants(id);
      if (!mounted) return;
      setState(() {
        _existingChallenge = challenge;
        _participantCount = participantCount;
        _populate(challenge);
        _initializing = false;
        _loadError = false;
      });
    } catch (e, s) {
      debugPrint('ERREUR CHARGEMENT FORMULAIRE CHALLENGE : $e\n$s');
      if (!mounted) return;
      setState(() {
        _loadError = true;
        _initializing = false;
      });
    }
  }

  void _populate(Challenge challenge) {
    _titleController.text = challenge.title;
    _descriptionController.text = challenge.description;
    _difficulty = challenge.difficulty;
    _xpController.text = challenge.xpReward.toString();
    _xpEdited = true;
    _startDate = challenge.startDate;
    _endDate = challenge.endDate;
    _imagePath = challenge.imagePath;
    _initialImagePath = challenge.imagePath;
    for (final task in _tasks) {
      task.dispose();
    }
    _tasks
      ..clear()
      ..addAll(challenge.tasks.map((task) => _TaskDraft(task: task)));
    if (_tasks.isEmpty) _tasks.add(_TaskDraft());
  }

  InputDecoration _pill(String label) => pillDecoration(label);

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------- Dates ----------

  Future<void> _pickDate({required bool isStart}) async {
    final today = DateTime.now();
    var firstDay = DateTime(today.year, today.month, today.day);
    if (_taskEditingLocked && !isStart && _endDate != null) {
      final existingEndDay = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
      );
      if (existingEndDay.isAfter(firstDay)) firstDay = existingEndDay;
    }
    final initial = (isStart ? _startDate : _endDate) ?? _startDate ?? firstDay;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDay) ? firstDay : initial,
      firstDate: firstDay,
      lastDate: firstDay.add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = DateTime(picked.year, picked.month, picked.day);
      } else {
        // La fin couvre toute la journée choisie.
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required bool isStart,
    required String? Function() validator,
  }) {
    return FormField<DateTime>(
      validator: (_) => validator(),
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: _loading || (_taskEditingLocked && isStart)
                ? null
                : () => _pickDate(isStart: isStart),
            child: InputDecorator(
              decoration: _pill(label).copyWith(
                suffixIcon: const Icon(Icons.calendar_today_outlined),
                errorText: state.errorText,
              ),
              child: Text(
                value == null ? 'Choisir une date' : formatChallengeDate(value),
                style: TextStyle(
                  color: value == null
                      ? AppTheme.textSecondary
                      : AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Image de couverture ----------

  Future<void> _chooseCover() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final path = await _service.pickCover(source);
      if (path == null) return; // annulé
      if (_imagePath != _initialImagePath) {
        await _service.deleteCover(_imagePath);
      }
      if (!mounted) return;
      setState(() => _imagePath = path);
    } catch (e, s) {
      debugPrint('ERREUR IMAGE CHALLENGE : $e\n$s');
      _snack('Impossible de récupérer l\'image : $e');
    }
  }

  Future<void> _removeCover() async {
    if (_imagePath != _initialImagePath) {
      await _service.deleteCover(_imagePath);
    }
    if (!mounted) return;
    setState(() => _imagePath = null);
  }

  Widget _buildCoverField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Image de couverture (facultatif)',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (_imagePath == null)
          Material(
            color: AppTheme.lavender.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              onTap: _loading ? null : _chooseCover,
              child: const SizedBox(
                width: double.infinity,
                height: 130,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppTheme.accent,
                      size: 36,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Ajouter une image',
                      style: TextStyle(color: AppTheme.primary),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                child: Image.file(
                  File(_imagePath!),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _loading ? null : _chooseCover,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Changer'),
                  ),
                  TextButton.icon(
                    onPressed: _loading ? null : _removeCover,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Retirer'),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  // ---------- Tâches ----------

  void _addTask() {
    if (_taskEditingLocked) return;
    if (_tasks.length >= ChallengeService.maxTasks) {
      _snack('Maximum ${ChallengeService.maxTasks} tâches');
      return;
    }
    setState(() => _tasks.add(_TaskDraft()));
  }

  void _removeTask(int index) {
    if (_taskEditingLocked) return;
    if (_tasks.length <= 1) {
      _snack('Un challenge doit avoir au moins une tâche');
      return;
    }
    setState(() => _tasks.removeAt(index).dispose());
  }

  void _reorderTasks(int oldIndex, int newIndex) {
    if (_taskEditingLocked) return;
    setState(() {
      _tasks.insert(newIndex, _tasks.removeAt(oldIndex));
    });
  }

  Future<void> _addTaskDate(_TaskDraft task) async {
    if (_loading || _taskEditingLocked) return;
    final start = _startDate;
    final end = _endDate;
    if (start == null || end == null || end.isBefore(start)) {
      _snack('Choisissez d’abord les dates du challenge');
      return;
    }
    final first = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: first,
      firstDate: first,
      lastDate: last,
    );
    if (!mounted || picked == null) return;
    if (task.scheduledDates.any(
      (date) =>
          ChallengeTaskLog.dateKey(date) == ChallengeTaskLog.dateKey(picked),
    )) {
      _snack('Cette date est déjà sélectionnée');
      return;
    }
    setState(() {
      task.scheduledDates.add(picked);
      task.scheduledDates.sort();
    });
  }

  Widget _buildTaskList() {
    final children = [
      for (var i = 0; i < _tasks.length; i++) _buildTaskRow(i, _tasks[i]),
    ];
    if (_taskEditingLocked) {
      return Column(children: children);
    }
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorderItem: _reorderTasks,
      children: children,
    );
  }

  Widget _buildTaskRow(int index, _TaskDraft task) {
    return Container(
      key: task.key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.background.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                if (_taskEditingLocked)
                  const Icon(Icons.drag_handle, color: AppTheme.borderColor)
                else
                  ReorderableDragStartListener(
                    index: index,
                    child: const Icon(
                      Icons.drag_handle,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  'Tâche ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Supprimer la tâche',
                  icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                  onPressed: _loading || _taskEditingLocked
                      ? null
                      : () => _removeTask(index),
                ),
              ],
            ),
            CustomTextField(
              controller: task.title,
              label: 'Titre',
              enabled: !_loading && !_taskEditingLocked,
              textCapitalization: TextCapitalization.sentences,
              decoration: _pill('Titre'),
              textInputAction: null,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Le titre de la tâche est obligatoire'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ChallengeType>(
              initialValue: task.type,
              onChanged: _loading || _taskEditingLocked
                  ? null
                  : (t) => setState(() {
                      if (t == null) return;
                      task.type = t;
                      task.unit = t.defaultUnit;
                    }),
              isExpanded: true,
              decoration: _pill('Type'),
              items: ChallengeType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final targetField = TextFormField(
                  controller: task.target,
                  enabled: !_loading && !_taskEditingLocked,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _pill('Objectif'),
                  validator: (v) {
                    final value = _TaskDraft.parseTarget(v ?? '');
                    if (value == null) return 'Nombre requis';
                    if (value <= 0) return 'Doit être > 0';
                    return null;
                  },
                );
                final unitField = DropdownButtonFormField<ChallengeUnit>(
                  key: ValueKey('${task.key}-${task.unit}'),
                  initialValue: task.unit,
                  onChanged: _loading || _taskEditingLocked
                      ? null
                      : (u) => setState(() => task.unit = u ?? task.unit),
                  isExpanded: true,
                  decoration: _pill('Unité'),
                  items: ChallengeUnit.values
                      .map(
                        (u) => DropdownMenuItem(value: u, child: Text(u.label)),
                      )
                      .toList(),
                );

                if (constraints.maxWidth < 280) {
                  return Column(
                    children: [
                      targetField,
                      const SizedBox(height: 12),
                      unitField,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: targetField),
                    const SizedBox(width: 10),
                    Expanded(child: unitField),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: task.description,
              enabled: !_loading && !_taskEditingLocked,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: _pill('Description (facultatif)'),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                task.scheduledDates.isEmpty
                    ? 'Dates : répartition automatique'
                    : 'Dates prévues (objectif total partagé)',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final date in task.scheduledDates)
                  InputChip(
                    label: Text(formatChallengeDate(date)),
                    onDeleted: _loading || _taskEditingLocked
                        ? null
                        : () =>
                              setState(() => task.scheduledDates.remove(date)),
                  ),
                if (!_taskEditingLocked)
                  ActionChip(
                    avatar: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Ajouter une date'),
                    onPressed: _loading ? null : () => _addTaskDate(task),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Envoi ----------

  String? _validateXp(String? v) {
    final xp = int.tryParse((v ?? '').trim());
    if (xp == null) return 'Nombre entier requis';
    if (xp < 0 || xp > ChallengeService.maxChallengeXp) {
      return 'Entre 0 et ${ChallengeService.maxChallengeXp}';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_canEdit) {
      _snack(
        _coachEditLocked
            ? 'Un coach ne peut plus modifier un challenge dès sa date de début'
            : 'Vous n\'avez pas le droit de modifier ce challenge',
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final challenge = Challenge(
      id: _existingChallenge?.id,
      title: _titleController.text,
      description: _descriptionController.text,
      difficulty: _difficulty,
      xpReward: int.parse(_xpController.text.trim()),
      startDate: _startDate!,
      endDate: _endDate!,
      status: _existingChallenge?.status ?? ChallengeStatus.active,
      imagePath: _imagePath,
      createdBy: _existingChallenge?.createdBy ?? 0,
      createdAt: _existingChallenge?.createdAt ?? now,
      updatedAt: now,
      tasks: _existingChallenge?.tasks ?? const [],
    );

    setState(() => _loading = true);
    try {
      final submittedTasks = _tasks.map((t) => t.toTask()).toList();
      if (_isEditMode) {
        await _service.updateChallenge(challenge, submittedTasks);
        final oldImage = _initialImagePath;
        if (oldImage != null && oldImage != _imagePath) {
          try {
            await _service.deleteCover(oldImage);
          } on FileSystemException catch (e, s) {
            debugPrint(
              'IMPOSSIBLE DE SUPPRIMER L\'ANCIENNE COUVERTURE : $e\n$s',
            );
          }
        }
      } else {
        await _service.createChallenge(challenge, submittedTasks);
      }
      if (!mounted) return;
      final coach = SessionManager.instance.currentUser?.role == UserRole.coach;
      final resubmitted =
          coach && _existingChallenge?.status == ChallengeStatus.rejected;
      _snack(
        resubmitted
            ? 'Challenge soumis à nouveau pour validation'
            : !_isEditMode && coach
            ? 'Challenge envoyé pour validation'
            : _isEditMode
            ? 'Challenge enregistré'
            : 'Challenge créé',
      );
      Navigator.pop(context, true);
    } on ChallengeException catch (e) {
      _snack(e.message);
    } catch (e, s) {
      debugPrint('ERREUR CRÉATION CHALLENGE : $e\n$s');
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- Écran ----------

  Widget _section(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: challengeCardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTheme.sectionTitle),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );

  Widget _screenBody(Widget child, {String? title}) => Column(
    children: [
      GradientHeader(
        title:
            title ??
            (_isEditMode ? 'Modifier le challenge' : 'Nouveau challenge'),
      ),
      Expanded(child: child),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: _screenBody(const Center(child: AppLoader(size: 48))),
      );
    }

    if (_loadError) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: _screenBody(
          Center(
            child: ElevatedButton.icon(
              onPressed: _loadExisting,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ),
          title: 'Challenge introuvable',
        ),
      );
    }

    if (!_canEdit) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: _screenBody(
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _coachEditLocked
                    ? 'Un coach ne peut plus modifier un challenge dès sa date de début.'
                    : 'Vous n\'avez pas le droit de modifier ce challenge.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _screenBody(
        Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              if (_generatedByAi) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.lavender,
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: AppTheme.primary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Généré par IA : relisez et modifiez avant de publier',
                          style: TextStyle(color: AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _section('Informations', [
                CustomTextField(
                  controller: _titleController,
                  label: 'Titre',
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _pill('Titre'),
                  textInputAction: null,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Le titre est obligatoire';
                    }
                    if (v.trim().length < ChallengeService.minTitleLength) {
                      return 'Au moins ${ChallengeService.minTitleLength} caractères';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _pill('Description'),
                ),
                const SizedBox(height: 20),
                _buildCoverField(),
              ]),
              const SizedBox(height: 16),
              _section('Dates et récompense', [
                const SizedBox(height: 16),
                DropdownButtonFormField<ChallengeDifficulty>(
                  initialValue: _difficulty,
                  isExpanded: true,
                  onChanged: _loading || _taskEditingLocked
                      ? null
                      : (d) => setState(() {
                          if (d == null) return;
                          _difficulty = d;
                          if (!_xpEdited) {
                            _xpController.text = d.defaultXp.toString();
                          }
                        }),
                  decoration: _pill('Difficulté'),
                  items: ChallengeDifficulty.values
                      .map(
                        (d) => DropdownMenuItem(
                          value: d,
                          child: Text('${d.label} (${d.defaultXp} XP)'),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _xpController,
                  enabled: !_loading && !_taskEditingLocked,
                  keyboardType: TextInputType.number,
                  decoration: _pill('XP récompense'),
                  onChanged: (_) => _xpEdited = true,
                  validator: _validateXp,
                ),
                const SizedBox(height: 16),
                _dateField(
                  label: 'Date de début',
                  value: _startDate,
                  isStart: true,
                  validator: () => _startDate == null
                      ? 'La date de début est obligatoire'
                      : null,
                ),
                const SizedBox(height: 16),
                _dateField(
                  label: 'Date de fin',
                  value: _endDate,
                  isStart: false,
                  validator: () {
                    if (_endDate == null) {
                      return 'La date de fin est obligatoire';
                    }
                    if (_startDate != null && !_endDate!.isAfter(_startDate!)) {
                      return 'La fin doit être après le début';
                    }
                    return null;
                  },
                ),
              ]),
              const SizedBox(height: 16),
              _section('Tâches', [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loading || _taskEditingLocked
                            ? null
                            : _addTask,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une tâche'),
                      ),
                    ),
                  ],
                ),
                if (_taskEditingLocked)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.lavender,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.primary),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Des participants ont rejoint ce challenge. '
                            'Ses tâches, sa difficulté, ses XP et sa date de '
                            'début sont verrouillés pour préserver leur progression.',
                            style: TextStyle(color: AppTheme.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                _buildTaskList(),
              ]),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Theme(
            data: Theme.of(context).copyWith(
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.surface,
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
            child: CustomButton(
              text: _isEditMode ? 'Enregistrer' : 'Créer le challenge',
              onPressed: _loading ? null : _submit,
              isLoading: _loading,
            ),
          ),
        ),
      ),
    );
  }
}
