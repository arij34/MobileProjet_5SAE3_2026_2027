import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../users/services/user_service.dart' show AuthException;
import '../models/food.dart';
import '../models/nutrition_enums.dart';
import '../repositories/food_repository.dart';
import '../services/nutrition_validation_service.dart';
import '../widgets/nutrition_ui.dart';

/// Création / modification d'un aliment personnalisé (valeurs pour 100 g).
class FoodFormScreen extends StatefulWidget {
  final Food? food;
  const FoodFormScreen({super.key, this.food});

  @override
  State<FoodFormScreen> createState() => _FoodFormScreenState();
}

class _FoodFormScreenState extends State<FoodFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fats;
  late FoodCategory _category;
  bool _saving = false;

  bool get _isEdit => widget.food?.id != null;

  @override
  void initState() {
    super.initState();
    final f = widget.food;
    _name = TextEditingController(text: f?.name ?? '');
    _calories = TextEditingController(text: f?.caloriesPer100g.toString() ?? '');
    _protein = TextEditingController(text: f?.proteinPer100g.toString() ?? '');
    _carbs = TextEditingController(text: f?.carbsPer100g.toString() ?? '');
    _fats = TextEditingController(text: f?.fatsPer100g.toString() ?? '');
    _category = f?.category ?? FoodCategory.other;
  }

  @override
  void dispose() {
    _name.dispose();
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fats.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final food = Food(
        id: widget.food?.id,
        name: _name.text,
        category: _category,
        caloriesPer100g: NutritionValidation.parseNumber(_calories.text) ?? 0,
        proteinPer100g: NutritionValidation.parseNumber(_protein.text) ?? 0,
        carbsPer100g: NutritionValidation.parseNumber(_carbs.text) ?? 0,
        fatsPer100g: NutritionValidation.parseNumber(_fats.text) ?? 0,
        isCustom: true,
        createdAt: widget.food?.createdAt ?? DateTime.now(),
      );
      if (_isEdit) {
        await FoodRepository.instance.update(food);
      } else {
        await FoodRepository.instance.create(food);
      }
      if (!mounted) return;
      showNSnack(context, _isEdit ? 'Aliment modifié.' : 'Aliment ajouté.',
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
        title: Text(_isEdit ? 'Modifier l\'aliment' : 'Nouvel aliment'),
        backgroundColor: NColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Valeurs pour 100 g',
                style: TextStyle(color: NColors.textSecondary)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: _dec('Nom de l\'aliment', Icons.restaurant),
              validator: NutritionValidation.foodName,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<FoodCategory>(
              initialValue: _category,
              decoration: _dec('Catégorie', Icons.category),
              items: FoodCategory.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (c) => setState(() => _category = c ?? _category),
            ),
            const SizedBox(height: 14),
            _num(_calories, 'Calories', 'kcal'),
            const SizedBox(height: 14),
            _num(_protein, 'Protéines', 'g'),
            const SizedBox(height: 14),
            _num(_carbs, 'Glucides', 'g'),
            const SizedBox(height: 14),
            _num(_fats, 'Lipides', 'g'),
            const SizedBox(height: 24),
            NButton(
                text: _isEdit ? 'Enregistrer' : 'Ajouter',
                icon: Icons.check,
                loading: _saving,
                onPressed: _save),
          ],
        ),
      ),
    );
  }

  Widget _num(TextEditingController c, String label, String suffix) =>
      TextFormField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: _dec(label, null, suffix: suffix),
        validator: (v) =>
            NutritionValidation.positiveOrZero(v, field: label),
      );

  InputDecoration _dec(String label, IconData? icon, {String? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        suffixText: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );
}
