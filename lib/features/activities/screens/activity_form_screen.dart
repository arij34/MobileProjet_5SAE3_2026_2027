import 'package:flutter/material.dart';

import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
import '../../users/services/user_service.dart' show AuthException;
import '../models/activity.dart';
import '../models/activity_category.dart';
import '../models/activity_level.dart';
import '../services/activity_service.dart';
import 'activity_ui.dart';

/// Formulaire de création / modification d'une activité.
///
/// - [gymId]    : salle à laquelle rattacher l'activité (obligatoire).
/// - [activity] : si fournie avec un id => modification ; avec un id null =>
///   création préremplie (utilisé par l'assistant IA) ; null => création vierge.
class ActivityFormScreen extends StatefulWidget {
  final int gymId;
  final Activity? activity;
  const ActivityFormScreen({super.key, required this.gymId, this.activity});

  @override
  State<ActivityFormScreen> createState() => _ActivityFormScreenState();
}

class _ActivityFormScreenState extends State<ActivityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _duration;
  late final TextEditingController _objective;
  late ActivityCategory _category;
  late ActivityLevel _level;
  bool _saving = false;

  bool get _isEdit => widget.activity?.id != null;

  @override
  void initState() {
    super.initState();
    final a = widget.activity;
    _name = TextEditingController(text: a?.name ?? '');
    _description = TextEditingController(text: a?.description ?? '');
    _duration = TextEditingController(text: (a?.durationMin ?? 60).toString());
    _objective = TextEditingController(text: a?.objective ?? '');
    _category = a?.category ?? ActivityCategory.other;
    _level = a?.level ?? ActivityLevel.beginner;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _duration.dispose();
    _objective.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final draft = Activity(
        id: widget.activity?.id,
        gymId: widget.gymId,
        name: _name.text,
        description: _description.text,
        category: _category,
        durationMin: int.tryParse(_duration.text.trim()) ?? 0,
        level: _level,
        objective: _objective.text,
        createdAt: widget.activity?.createdAt ?? DateTime.now(),
      );
      if (_isEdit) {
        await ActivityService.instance.update(draft);
      } else {
        await ActivityService.instance.create(draft);
      }
      if (!mounted) return;
      showASnack(context, _isEdit ? 'Activité modifiée.' : 'Activité créée.',
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
        title: Text(_isEdit ? 'Modifier l\'activité' : 'Nouvelle activité'),
        backgroundColor: AColors.violetDark,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            CustomTextField(
              controller: _name,
              label: 'Nom de l\'activité',
              icon: Icons.fitness_center,
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'Au moins 3 caractères.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              maxLines: 3,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ActivityCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Catégorie',
                prefixIcon: Icon(Icons.category),
              ),
              items: ActivityCategory.values
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (c) => setState(() => _category = c ?? _category),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _duration,
              label: 'Durée (minutes)',
              icon: Icons.timer,
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n <= 0 || n > 600) {
                  return 'Durée entre 1 et 600 minutes.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ActivityLevel>(
              initialValue: _level,
              decoration: const InputDecoration(
                labelText: 'Niveau',
                prefixIcon: Icon(Icons.signal_cellular_alt),
              ),
              items: ActivityLevel.values
                  .map((l) =>
                      DropdownMenuItem(value: l, child: Text(l.label)))
                  .toList(),
              onChanged: (l) => setState(() => _level = l ?? _level),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _objective,
              label: 'Objectif sportif (facultatif)',
              icon: Icons.flag,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 28),
            CustomButton(
              text: _isEdit ? 'Enregistrer' : 'Créer l\'activité',
              icon: Icons.check,
              isLoading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
