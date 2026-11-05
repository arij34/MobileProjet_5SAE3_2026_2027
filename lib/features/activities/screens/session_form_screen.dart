import 'package:flutter/material.dart';

import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../gyms/models/gym_coach.dart';
import '../../gyms/services/gym_coach_service.dart';
import '../../users/services/user_service.dart' show AuthException;
import '../models/activity.dart';
import '../models/activity_session.dart';
import '../services/activity_service.dart';
import '../services/session_service.dart';
import 'activity_ui.dart';

/// Formulaire de création / modification d'une séance (créneau du planning).
class SessionFormScreen extends StatefulWidget {
  final int gymId;
  final ActivitySession? session; // null => création
  const SessionFormScreen({super.key, required this.gymId, this.session});

  @override
  State<SessionFormScreen> createState() => _SessionFormScreenState();
}

class _SessionFormScreenState extends State<SessionFormScreen> {
  final _capacity = TextEditingController(text: '10');
  List<Activity> _activities = [];
  List<GymCoach> _coaches = [];
  Activity? _activity;
  int? _coachId;
  DateTime? _date;
  TimeOfDay? _time;
  int _durationMin = 60;
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.session?.id != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _capacity.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final activities = await ActivityService.instance.getForGym(widget.gymId);
      final coaches = await GymCoachService.instance.getCoaches(widget.gymId);
      _activities = activities;
      final s = widget.session;
      if (s != null) {
        _activity = activities.firstWhere(
          (a) => a.id == s.activityId,
          orElse: () => activities.isNotEmpty
              ? activities.first
              : throw AuthException('Activité introuvable.'),
        );
        _coachId = s.coachId;
        _date = DateTime(s.startAt.year, s.startAt.month, s.startAt.day);
        _time = TimeOfDay(hour: s.startAt.hour, minute: s.startAt.minute);
        _durationMin = s.durationMin;
        _capacity.text = s.capacityMax.toString();
      } else if (activities.isNotEmpty) {
        _activity = activities.first;
        _durationMin = _activity!.durationMin;
      }
      // On ne garde que les coachs actifs de la salle.
      _coaches = coaches.where((c) => c.isActive).toList();
    } on AuthException catch (e) {
      if (mounted) showASnack(context, e.message, color: AColors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (_activity == null) {
      showASnack(context, 'Choisissez une activité.', color: AColors.red);
      return;
    }
    if (_date == null || _time == null) {
      showASnack(context, 'Choisissez la date et l\'heure.',
          color: AColors.red);
      return;
    }
    final capacity = int.tryParse(_capacity.text.trim()) ?? 0;
    if (capacity <= 0) {
      showASnack(context, 'Capacité invalide.', color: AColors.red);
      return;
    }
    final startAt = DateTime(_date!.year, _date!.month, _date!.day,
        _time!.hour, _time!.minute);

    setState(() => _saving = true);
    try {
      final draft = ActivitySession(
        id: widget.session?.id,
        activityId: _activity!.id!,
        coachId: _coachId,
        startAt: startAt,
        durationMin: _durationMin,
        capacityMax: capacity,
        createdAt: widget.session?.createdAt ?? DateTime.now(),
      );
      if (_isEdit) {
        await SessionService.instance.update(draft);
      } else {
        await SessionService.instance.create(draft);
      }
      if (!mounted) return;
      showASnack(context, _isEdit ? 'Séance modifiée.' : 'Séance ajoutée.',
          color: AColors.green);
      Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (mounted) showASnack(context, e.message, color: AColors.red);
    } catch (e) {
      if (mounted) showASnack(context, 'Erreur : $e', color: AColors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AColors.grayLight,
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier la séance' : 'Nouvelle séance'),
        backgroundColor: AColors.violetDark,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: AppLoader())
          : _activities.isEmpty && _activity == null
              ? _noActivity()
              : _form(),
    );
  }

  Widget _noActivity() => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Créez d\'abord une activité avant de planifier une séance.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AColors.textSecondary),
          ),
        ),
      );

  Widget _form() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        DropdownButtonFormField<Activity>(
          initialValue: _activity,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Activité',
            prefixIcon: Icon(Icons.fitness_center),
          ),
          items: _activities
              .map((a) => DropdownMenuItem(
                    value: a,
                    child: Text('${a.name} · ${a.category.label}',
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: _isEdit
              ? null // l'activité d'une séance ne change pas après création
              : (a) => setState(() {
                    _activity = a;
                    if (a != null) _durationMin = a.durationMin;
                  }),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int?>(
          initialValue: _coachId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Coach (facultatif)',
            prefixIcon: Icon(Icons.sports),
          ),
          items: [
            const DropdownMenuItem<int?>(
                value: null, child: Text('Aucun coach')),
            ..._coaches.map((c) => DropdownMenuItem<int?>(
                  value: c.coachId,
                  child: Text(c.coachName ?? 'Coach',
                      overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: (v) => setState(() => _coachId = v),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _pickerTile(
                icon: Icons.calendar_today,
                label: 'Date',
                value: _date == null
                    ? 'Choisir'
                    : '${ActivitySession.two(_date!.day)}/'
                        '${ActivitySession.two(_date!.month)}/${_date!.year}',
                onTap: _pickDate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _pickerTile(
                icon: Icons.access_time,
                label: 'Heure',
                value: _time == null ? 'Choisir' : _time!.format(context),
                onTap: _pickTime,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _capacity,
          label: 'Capacité maximale',
          icon: Icons.groups,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 16),
        _durationField(),
        const SizedBox(height: 28),
        CustomButton(
          text: _isEdit ? 'Enregistrer' : 'Ajouter la séance',
          icon: Icons.check,
          isLoading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }

  Widget _durationField() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AColors.lilac),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer, color: AColors.textSecondary),
            const SizedBox(width: 12),
            Text('Durée : $_durationMin min',
                style: const TextStyle(color: AColors.violetDark)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              color: AColors.violet,
              onPressed: _durationMin > 15
                  ? () => setState(() => _durationMin -= 15)
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: AColors.violet,
              onPressed: _durationMin < 600
                  ? () => setState(() => _durationMin += 15)
                  : null,
            ),
          ],
        ),
      );

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AColors.lilac),
        ),
        child: Row(
          children: [
            Icon(icon, color: AColors.textSecondary, size: 20),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AColors.textSecondary, fontSize: 11)),
                Text(value,
                    style: const TextStyle(
                        color: AColors.violetDark,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
