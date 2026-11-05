import 'package:flutter/material.dart';

import '../../../core/widgets/app_loader.dart';
import '../../users/services/user_service.dart' show AuthException;
import '../models/food.dart';
import '../models/meal.dart';
import '../models/meal_item.dart';
import '../models/nutrition_enums.dart';
import '../repositories/food_repository.dart';
import '../repositories/meal_repository.dart';
import '../repositories/nutrition_repository.dart';
import '../services/nutrition_calculator.dart';
import '../services/nutrition_gemini_service.dart' show ProposedMeal;
import '../services/nutrition_validation_service.dart';
import '../widgets/nutrition_ui.dart';

/// Une ligne du repas en cours d'édition (aliment + quantité).
class _Row {
  final Food food;
  double grams;
  _Row(this.food, this.grams);
  MealItem get item => NutritionCalculator.scale(food, grams);
}

/// Création / modification d'un repas (ou préremplissage depuis une proposition IA).
class MealFormScreen extends StatefulWidget {
  final DateTime date;
  final Meal? meal; // édition
  final ProposedMeal? proposal; // préremplissage depuis le Coach IA
  const MealFormScreen({
    super.key,
    required this.date,
    this.meal,
    this.proposal,
  });

  @override
  State<MealFormScreen> createState() => _MealFormScreenState();
}

class _MealFormScreenState extends State<MealFormScreen> {
  MealType _type = MealType.breakfast;
  final List<_Row> _rows = [];
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.meal?.id != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      if (widget.proposal != null) {
        _type = widget.proposal!.suggestedType;
        for (final it in widget.proposal!.items) {
          _rows.add(_Row(it.food, it.grams));
        }
      } else if (widget.meal != null) {
        _type = widget.meal!.type;
        for (final it in widget.meal!.items) {
          final food = await FoodRepository.instance.getById(it.foodId);
          if (food != null) _rows.add(_Row(food, it.quantity));
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _calories => _rows.fold(0, (s, r) => s + r.item.calories);
  double get _proteins => _rows.fold(0, (s, r) => s + r.item.proteins);
  double get _carbs => _rows.fold(0, (s, r) => s + r.item.carbs);
  double get _fats => _rows.fold(0, (s, r) => s + r.item.fats);

  Future<void> _pickFood() async {
    final food = await showModalBottomSheet<Food>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _FoodPickerSheet(),
    );
    if (food == null || !mounted) return;
    final grams = await _askQuantity();
    if (grams == null) return;
    await _warnIfAllergen(food);
    setState(() => _rows.add(_Row(food, grams)));
  }

  Future<double?> _askQuantity({double initial = 100}) async {
    final c = TextEditingController(text: initial.toStringAsFixed(0));
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quantité'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Grammes', suffixText: 'g'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () {
              final err = NutritionValidation.quantity(c.text);
              if (err != null) {
                showNSnack(ctx, err, color: NColors.danger);
                return;
              }
              Navigator.pop(ctx, NutritionValidation.parseNumber(c.text));
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Avertit (sans bloquer) si l'aliment correspond à une allergie du profil.
  Future<void> _warnIfAllergen(Food food) async {
    final profile = await NutritionRepository.instance.getProfile();
    final allergies = profile?.allergyList ?? const [];
    final hits = MealRepository.matchAllergies([food], allergies);
    if (hits.isNotEmpty && mounted) {
      showNSnack(context, '⚠️ ${food.name} correspond à une allergie déclarée.',
          color: NColors.danger);
    }
  }

  Future<void> _editQuantity(int index) async {
    final grams = await _askQuantity(initial: _rows[index].grams);
    if (grams != null) setState(() => _rows[index].grams = grams);
  }

  Future<void> _save() async {
    if (_rows.isEmpty) {
      showNSnack(context, 'Ajoutez au moins un aliment.',
          color: NColors.danger);
      return;
    }
    setState(() => _saving = true);
    try {
      final items = _rows.map((r) => r.item).toList();
      if (_isEdit) {
        await MealRepository.instance.updateMeal(
            mealId: widget.meal!.id!, type: _type, date: widget.date, items: items);
      } else {
        await MealRepository.instance
            .createMeal(type: _type, date: widget.date, items: items);
      }
      if (!mounted) return;
      showNSnack(context, _isEdit ? 'Repas modifié.' : 'Repas ajouté.',
          color: NColors.calories);
      Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (mounted) showNSnack(context, e.message, color: NColors.danger);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NColors.bg,
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier le repas' : 'Nouveau repas'),
        backgroundColor: NColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: AppLoader(color: NColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const Text('Type de repas',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: NColors.textDark)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: MealType.values.map((t) {
                    final sel = t == _type;
                    return ChoiceChip(
                      label: Text(t.label),
                      selected: sel,
                      showCheckmark: false,
                      avatar: Icon(t.icon,
                          size: 18,
                          color: sel ? Colors.white : NColors.primary),
                      selectedColor: NColors.primary,
                      backgroundColor: NColors.lavender,
                      labelStyle: TextStyle(
                          color: sel ? Colors.white : NColors.textDark,
                          fontWeight: FontWeight.w600),
                      onSelected: (_) => setState(() => _type = t),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Text('Aliments',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: NColors.textDark)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _pickFood,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajouter'),
                      style:
                          TextButton.styleFrom(foregroundColor: NColors.primary),
                    ),
                  ],
                ),
                if (_rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('Aucun aliment. Touchez « Ajouter ».',
                        style: TextStyle(color: NColors.textSecondary)),
                  )
                else
                  ..._rows.asMap().entries.map((e) => _rowCard(e.key, e.value)),
                const SizedBox(height: 16),
                _totalsCard(),
                const SizedBox(height: 18),
                NButton(
                    text: _isEdit ? 'Enregistrer' : 'Ajouter le repas',
                    icon: Icons.check,
                    loading: _saving,
                    onPressed: _save),
              ],
            ),
    );
  }

  Widget _rowCard(int index, _Row row) {
    final it = row.item;
    return NCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.food.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: NColors.textDark)),
                const SizedBox(height: 2),
                Text(
                    '${row.grams.round()} g · ${it.calories.round()} kcal · '
                    'P ${it.proteins.round()} / G ${it.carbs.round()} / '
                    'L ${it.fats.round()}',
                    style: const TextStyle(
                        color: NColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
              onPressed: () => _editQuantity(index),
              icon: const Icon(Icons.edit, size: 20, color: NColors.primary)),
          IconButton(
              onPressed: () => setState(() => _rows.removeAt(index)),
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: NColors.danger)),
        ],
      ),
    );
  }

  Widget _totalsCard() => NCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _total('${_calories.round()}', 'kcal', NColors.calories),
            _total('${_proteins.round()}', 'Prot.', NColors.protein),
            _total('${_carbs.round()}', 'Gluc.', NColors.carbs),
            _total('${_fats.round()}', 'Lip.', NColors.fats),
          ],
        ),
      );

  Widget _total(String value, String label, Color color) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16, color: color)),
          Text(label,
              style:
                  const TextStyle(color: NColors.textSecondary, fontSize: 11)),
        ],
      );
}

/// Feuille de sélection d'un aliment (recherche dans le catalogue).
class _FoodPickerSheet extends StatefulWidget {
  const _FoodPickerSheet();

  @override
  State<_FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<_FoodPickerSheet> {
  final _search = TextEditingController();
  List<Food> _foods = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final foods = await FoodRepository.instance.getAll(search: _search.text);
    if (mounted) {
      setState(() {
        _foods = foods;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 12),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: NColors.lavender,
                  borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              onChanged: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Rechercher un aliment...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: NColors.bg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: AppLoader(color: NColors.primary))
                  : _foods.isEmpty
                      ? const Center(
                          child: Text('Aucun aliment trouvé.',
                              style:
                                  TextStyle(color: NColors.textSecondary)))
                      : ListView.builder(
                          itemCount: _foods.length,
                          itemBuilder: (_, i) {
                            final f = _foods[i];
                            return ListTile(
                              title: Text(f.name),
                              subtitle: Text(
                                  '${f.caloriesPer100g.round()} kcal / 100 g · '
                                  '${f.category.label}'),
                              trailing: const Icon(Icons.add_circle_outline,
                                  color: NColors.primary),
                              onTap: () => Navigator.pop(context, f),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
