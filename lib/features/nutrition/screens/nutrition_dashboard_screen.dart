import 'package:flutter/material.dart';

import '../../../core/session/session_manager.dart';
import '../../../core/widgets/app_loader.dart';
import '../models/nutrition_profile.dart';
import '../models/weight_entry.dart';
import '../repositories/meal_repository.dart';
import '../repositories/nutrition_repository.dart';
import '../services/nutrition_validation_service.dart';
import '../widgets/macro_ring.dart';
import '../widgets/nutrition_ui.dart';
import '../widgets/weight_chart.dart';
import 'meal_form_screen.dart';
import 'nutrition_profile_screen.dart';

/// Tableau de bord nutritionnel du jour (calories, macros, eau, poids).
class NutritionDashboardScreen extends StatefulWidget {
  const NutritionDashboardScreen({super.key});

  @override
  State<NutritionDashboardScreen> createState() =>
      _NutritionDashboardScreenState();
}

class _NutritionDashboardScreenState extends State<NutritionDashboardScreen> {
  static const double _waterGoalMl = 2000;

  bool _loading = true;
  NutritionProfile? _profile;
  NutritionTotals _totals = const NutritionTotals();
  double _waterMl = 0;
  List<WeightEntry> _weights = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final today = DateTime.now();
      final profile = await NutritionRepository.instance.getProfile();
      final totals = await MealRepository.instance.totalsForDate(today);
      final water = await NutritionRepository.instance.waterForDate(today);
      final weights = await NutritionRepository.instance.getWeightHistory();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _totals = totals;
        _waterMl = water;
        _weights = weights;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addMeal() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MealFormScreen(date: DateTime.now())),
    );
    if (changed == true) _load();
  }

  Future<void> _addWater(double ml) async {
    await NutritionRepository.instance.addWater(ml);
    _load();
  }

  Future<void> _addWeight() async {
    final controller = TextEditingController(
        text: _weights.isNotEmpty ? _weights.last.weight.toString() : '');
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enregistrer mon poids'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
              labelText: 'Poids (kg)', suffixText: 'kg'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              final err = NutritionValidation.weight(controller.text);
              if (err != null) {
                showNSnack(ctx, err, color: NColors.danger);
                return;
              }
              Navigator.pop(ctx, NutritionValidation.parseNumber(controller.text));
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (value != null) {
      await NutritionRepository.instance.addWeight(value);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionManager.instance.currentUser;
    if (_loading) return const Center(child: AppLoader(color: NColors.primary));

    final p = _profile;
    final hasGoals = p != null && p.dailyCaloriesGoal > 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text('Bonjour ${user?.firstName ?? ''} 👋',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: NColors.textDark)),
          const Text('Votre bilan nutritionnel du jour',
              style: TextStyle(color: NColors.textSecondary)),
          const SizedBox(height: 16),

          if (!hasGoals) _profilePrompt(),
          if (hasGoals) ...[
            _caloriesCard(p),
            const SizedBox(height: 14),
            _macrosCard(p),
          ],
          const SizedBox(height: 14),
          _waterCard(),
          const SizedBox(height: 14),
          _weightCard(),
          const SizedBox(height: 18),
          NButton(
              text: 'Ajouter un repas',
              icon: Icons.add,
              onPressed: _addMeal),
        ],
      ),
    );
  }

  Widget _profilePrompt() => NCard(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const NutritionProfileScreen()),
          );
          _load();
        },
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: NColors.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Renseignez votre profil pour calculer vos objectifs '
                'caloriques et de macronutriments.',
                style: TextStyle(color: NColors.textDark),
              ),
            ),
            const Icon(Icons.chevron_right, color: NColors.textSecondary),
          ],
        ),
      );

  Widget _caloriesCard(NutritionProfile p) => NCard(
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Calories',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: NColors.textDark)),
            ),
            const SizedBox(height: 12),
            CaloriesRing(
                consumed: _totals.calories, goal: p.dailyCaloriesGoal),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniStat('Consommées', '${_totals.calories.round()}',
                    NColors.calories),
                _miniStat('Objectif', '${p.dailyCaloriesGoal.round()}',
                    NColors.primary),
                _miniStat(
                    'Restantes',
                    '${(p.dailyCaloriesGoal - _totals.calories).round()}',
                    NColors.carbs),
              ],
            ),
          ],
        ),
      );

  Widget _miniStat(String label, String value, Color color) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: NColors.textSecondary)),
        ],
      );

  Widget _macrosCard(NutritionProfile p) => NCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Macronutriments',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: NColors.textDark)),
            const SizedBox(height: 14),
            MacroBar(
                label: 'Protéines',
                consumed: _totals.proteins,
                goal: p.proteinGoal,
                color: NColors.protein),
            const SizedBox(height: 12),
            MacroBar(
                label: 'Glucides',
                consumed: _totals.carbs,
                goal: p.carbsGoal,
                color: NColors.carbs),
            const SizedBox(height: 12),
            MacroBar(
                label: 'Lipides',
                consumed: _totals.fats,
                goal: p.fatsGoal,
                color: NColors.fats),
          ],
        ),
      );

  Widget _waterCard() {
    final liters = _waterMl / 1000;
    final goalL = _waterGoalMl / 1000;
    final ratio = (_waterMl / _waterGoalMl).clamp(0.0, 1.0);
    return NCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_drink, color: NColors.water),
              const SizedBox(width: 8),
              const Text('Eau',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: NColors.textDark)),
              const Spacer(),
              Text(
                  '${liters.toStringAsFixed(1)} / '
                  '${goalL.toStringAsFixed(1)} L',
                  style: const TextStyle(
                      color: NColors.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 9,
              backgroundColor: NColors.lavender,
              valueColor: const AlwaysStoppedAnimation(NColors.water),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addWater(250),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('250 ml'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: NColors.water,
                      side: const BorderSide(color: NColors.water)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addWater(500),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('500 ml'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: NColors.water,
                      side: const BorderSide(color: NColors.water)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weightCard() {
    final latest = _weights.isNotEmpty ? _weights.last.weight : null;
    return NCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_weight_outlined,
                  color: NColors.primary),
              const SizedBox(width: 8),
              const Text('Suivi du poids',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: NColors.textDark)),
              const Spacer(),
              if (latest != null)
                Text('${latest.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                        color: NColors.primary, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          WeightChart(entries: _weights),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addWeight,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Enregistrer mon poids'),
            style: OutlinedButton.styleFrom(
                foregroundColor: NColors.primary,
                side: const BorderSide(color: NColors.primary)),
          ),
        ],
      ),
    );
  }
}
