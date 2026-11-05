import 'package:flutter/material.dart';

import '../../../core/widgets/app_loader.dart';
import '../../users/services/user_service.dart' show AuthException;
import '../models/meal.dart';
import '../repositories/meal_repository.dart';
import '../widgets/nutrition_ui.dart';
import 'foods_catalog_screen.dart';
import 'meal_form_screen.dart';

/// Journal alimentaire : les repas d'une journée, regroupés par type.
class FoodJournalScreen extends StatefulWidget {
  const FoodJournalScreen({super.key});

  @override
  State<FoodJournalScreen> createState() => _FoodJournalScreenState();
}

class _FoodJournalScreenState extends State<FoodJournalScreen> {
  DateTime _date = DateTime.now();
  List<Meal> _meals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final meals = await MealRepository.instance.getMealsForDate(_date);
    if (mounted) {
      setState(() {
        _meals = meals;
        _loading = false;
      });
    }
  }

  void _shiftDay(int days) {
    final next = _date.add(Duration(days: days));
    if (next.isAfter(DateTime.now())) return; // pas de date future
    setState(() => _date = next);
    _load();
  }

  Future<void> _addMeal() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MealFormScreen(date: _date)),
    );
    if (changed == true) _load();
  }

  Future<void> _editMeal(Meal meal) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MealFormScreen(date: _date, meal: meal)),
    );
    if (changed == true) _load();
  }

  Future<void> _deleteMeal(Meal meal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le repas'),
        content: Text('Supprimer ce ${meal.type.label.toLowerCase()} ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: NColors.danger),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await MealRepository.instance.deleteMeal(meal.id!);
      _load();
    } on AuthException catch (e) {
      if (mounted) showNSnack(context, e.message, color: NColors.danger);
    }
  }

  double get _dayCalories => _meals.fold(0, (s, m) => s + m.totalCalories);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: NColors.primary,
        onPressed: _addMeal,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un repas'),
      ),
      body: Column(
      children: [
        _header(),
        _dateBar(),
        Expanded(
          child: _loading
              ? const Center(child: AppLoader(color: NColors.primary))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _meals.isEmpty
                      ? ListView(children: const [
                          Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: Center(
                              child: Text('Aucun repas pour ce jour.',
                                  style:
                                      TextStyle(color: NColors.textSecondary)),
                            ),
                          )
                        ])
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                          children: _meals.map(_mealCard).toList(),
                        ),
                ),
        ),
      ],
    ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Row(
          children: [
            const Expanded(
              child: Text('Journal alimentaire',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: NColors.textDark)),
            ),
            IconButton(
              tooltip: 'Catalogue d\'aliments',
              icon: const Icon(Icons.menu_book, color: NColors.primary),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FoodsCatalogScreen()),
              ),
            ),
          ],
        ),
      );

  Widget _dateBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: NCard(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                  onPressed: () => _shiftDay(-1),
                  icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _isToday
                          ? 'Aujourd\'hui'
                          : Meal.dateKey(_date).split('-').reversed.join('/'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: NColors.textDark),
                    ),
                    Text('${_dayCalories.round()} kcal',
                        style: const TextStyle(
                            color: NColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                  onPressed: _isToday ? null : () => _shiftDay(1),
                  icon: const Icon(Icons.chevron_right)),
            ],
          ),
        ),
      );

  Widget _mealCard(Meal meal) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: NCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(meal.type.icon, color: NColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(meal.type.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: NColors.textDark,
                          fontSize: 15)),
                  const Spacer(),
                  Text('${meal.totalCalories.round()} kcal',
                      style: const TextStyle(
                          color: NColors.primary, fontWeight: FontWeight.w700)),
                  PopupMenuButton<String>(
                    onSelected: (v) =>
                        v == 'edit' ? _editMeal(meal) : _deleteMeal(meal),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Modifier')),
                      PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                    ],
                  ),
                ],
              ),
              const Divider(height: 14),
              ...meal.items.map((it) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                              '${it.foodName ?? 'Aliment'} · ${it.quantity.round()} g',
                              style:
                                  const TextStyle(color: NColors.textDark)),
                        ),
                        Text('${it.calories.round()} kcal',
                            style: const TextStyle(
                                color: NColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  )),
              const SizedBox(height: 6),
              Text(
                  'Protéines ${meal.totalProteins.round()} g · '
                  'Glucides ${meal.totalCarbs.round()} g · '
                  'Lipides ${meal.totalFats.round()} g',
                  style: const TextStyle(
                      color: NColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      );
}
