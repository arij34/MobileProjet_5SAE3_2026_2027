import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/app_loader.dart';
import '../../users/models/user_gender.dart';
import '../../users/services/user_service.dart' show AuthException;
import '../models/nutrition_enums.dart';
import '../models/nutrition_profile.dart';
import '../repositories/nutrition_repository.dart';
import '../services/nutrition_calculator.dart';
import '../services/nutrition_validation_service.dart';
import '../widgets/nutrition_ui.dart';

/// Profil nutritionnel : données corporelles, objectif, calculs et sauvegarde.
class NutritionProfileScreen extends StatefulWidget {
  const NutritionProfileScreen({super.key});

  @override
  State<NutritionProfileScreen> createState() => _NutritionProfileScreenState();
}

class _NutritionProfileScreenState extends State<NutritionProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _age = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _preferences = TextEditingController();
  final _allergies = TextEditingController();

  UserGender? _sex;
  NutritionActivityLevel _activity = NutritionActivityLevel.moderate;
  NutritionGoal _goal = NutritionGoal.maintain;

  NutritionProfile? _profile;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    _preferences.dispose();
    _allergies.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await NutritionRepository.instance.getOrDraftProfile();
      _profile = p;
      _age.text = p.age?.toString() ?? '';
      _height.text = p.heightCm?.toString() ?? '';
      _weight.text = p.weightKg?.toString() ?? '';
      _preferences.text = p.foodPreferences;
      _allergies.text = p.allergies;
      _sex = p.sex;
      _activity = p.activityLevel;
      _goal = p.goal;
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Objectifs calculés en direct si les champs nécessaires sont valides.
  NutritionTargets? get _liveTargets {
    final age = int.tryParse(_age.text.trim());
    final h = NutritionValidation.parseNumber(_height.text);
    final w = NutritionValidation.parseNumber(_weight.text);
    if (age == null || h == null || w == null || _sex == null) return null;
    if (age < 10 || h < 100 || w < 25) return null;
    return NutritionCalculator.targets(
      weightKg: w,
      heightCm: h,
      age: age,
      sex: _sex!,
      activity: _activity,
      goal: _goal,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sex == null) {
      showNSnack(context, 'Sélectionnez votre sexe.', color: NColors.danger);
      return;
    }
    final targets = _liveTargets;
    if (targets == null) {
      showNSnack(context, 'Vérifiez vos informations.', color: NColors.danger);
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = _profile!.copyWith(
        age: int.parse(_age.text.trim()),
        sex: _sex,
        heightCm: NutritionValidation.parseNumber(_height.text),
        weightKg: NutritionValidation.parseNumber(_weight.text),
        activityLevel: _activity,
        goal: _goal,
        dailyCaloriesGoal: targets.calories,
        proteinGoal: targets.proteins,
        carbsGoal: targets.carbs,
        fatsGoal: targets.fats,
        foodPreferences: _preferences.text.trim(),
        allergies: _allergies.text.trim(),
      );
      await NutritionRepository.instance.saveProfile(updated);
      // Un poids enregistré dans le profil alimente aussi le suivi du poids.
      if (updated.weightKg != null) {
        await NutritionRepository.instance.addWeight(updated.weightKg!);
      }
      if (!mounted) return;
      showNSnack(context, 'Profil enregistré.', color: NColors.calories);
    } on AuthException catch (e) {
      if (mounted) showNSnack(context, e.message, color: NColors.danger);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: AppLoader(color: NColors.primary));
    final targets = _liveTargets;
    final bmi = (NutritionValidation.parseNumber(_weight.text) != null &&
            NutritionValidation.parseNumber(_height.text) != null &&
            NutritionValidation.parseNumber(_height.text)! > 0)
        ? NutritionCalculator.bmi(
            NutritionValidation.parseNumber(_weight.text)!,
            NutritionValidation.parseNumber(_height.text)!)
        : null;

    return Form(
      key: _formKey,
      onChanged: () => setState(() {}), // recalcul en direct
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const Text('Mon profil nutritionnel',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: NColors.textDark)),
          const SizedBox(height: 16),
          NCard(
            child: Column(
              children: [
                _numField(_age, 'Âge', 'ans',
                    validator: NutritionValidation.age, integer: true),
                const SizedBox(height: 14),
                DropdownButtonFormField<UserGender>(
                  initialValue: _sex,
                  decoration: _dec('Sexe', Icons.wc),
                  items: UserGender.values
                      .map((g) =>
                          DropdownMenuItem(value: g, child: Text(g.label)))
                      .toList(),
                  onChanged: (g) => setState(() => _sex = g),
                  validator: (v) => v == null ? 'Sélectionnez votre sexe.' : null,
                ),
                const SizedBox(height: 14),
                _numField(_height, 'Taille', 'cm',
                    validator: NutritionValidation.height),
                const SizedBox(height: 14),
                _numField(_weight, 'Poids', 'kg',
                    validator: NutritionValidation.weight),
                const SizedBox(height: 14),
                DropdownButtonFormField<NutritionActivityLevel>(
                  initialValue: _activity,
                  isExpanded: true,
                  decoration: _dec('Niveau d\'activité', Icons.directions_run),
                  items: NutritionActivityLevel.values
                      .map((a) => DropdownMenuItem(
                          value: a,
                          child: Text(a.label,
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (a) =>
                      setState(() => _activity = a ?? _activity),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<NutritionGoal>(
                  initialValue: _goal,
                  isExpanded: true,
                  decoration: _dec('Objectif', Icons.flag),
                  items: NutritionGoal.values
                      .map((g) =>
                          DropdownMenuItem(value: g, child: Text(g.label)))
                      .toList(),
                  onChanged: (g) => setState(() => _goal = g ?? _goal),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          NCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _preferences,
                  decoration: _dec(
                      'Préférences alimentaires (facultatif)', Icons.favorite),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _allergies,
                  decoration: _dec(
                      'Allergies (séparées par des virgules)',
                      Icons.warning_amber),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _resultsCard(bmi, targets),
          const SizedBox(height: 18),
          NButton(
              text: 'Enregistrer le profil',
              icon: Icons.check,
              loading: _saving,
              onPressed: _save),
          const SizedBox(height: 8),
          const Text(
            'Ces valeurs sont des estimations et ne remplacent pas l\'avis '
            'd\'un professionnel de santé.',
            textAlign: TextAlign.center,
            style: TextStyle(color: NColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _resultsCard(double? bmi, NutritionTargets? t) => NCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Estimations',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: NColors.textDark)),
            const SizedBox(height: 12),
            if (bmi == null && t == null)
              const Text(
                'Complétez âge, sexe, taille et poids pour voir vos objectifs.',
                style: TextStyle(color: NColors.textSecondary),
              )
            else ...[
              if (bmi != null)
                _resultRow('IMC',
                    '${bmi.toStringAsFixed(1)} — ${NutritionCalculator.bmiCategory(bmi)}'),
              if (t != null) ...[
                _resultRow('Métabolisme de base (BMR)', '${t.bmr.round()} kcal'),
                _resultRow('Dépense journalière (TDEE)', '${t.tdee.round()} kcal'),
                const Divider(height: 20),
                _resultRow('Objectif calorique', '${t.calories.round()} kcal',
                    strong: true),
                _resultRow('Protéines', '${t.proteins.round()} g'),
                _resultRow('Glucides', '${t.carbs.round()} g'),
                _resultRow('Lipides', '${t.fats.round()} g'),
              ],
            ],
          ],
        ),
      );

  Widget _resultRow(String label, String value, {bool strong = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: NColors.textSecondary,
                    fontWeight: strong ? FontWeight.w700 : FontWeight.normal)),
            Text(value,
                style: TextStyle(
                    color: strong ? NColors.primary : NColors.textDark,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _numField(TextEditingController c, String label, String suffix,
      {String? Function(String?)? validator, bool integer = false}) {
    return TextFormField(
      controller: c,
      keyboardType: integer
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: integer
          ? [FilteringTextInputFormatter.digitsOnly]
          : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: _dec(label, null, suffix: suffix),
      validator: validator,
    );
  }

  InputDecoration _dec(String label, IconData? icon, {String? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        suffixText: suffix,
        filled: true,
        fillColor: NColors.bg,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );
}
