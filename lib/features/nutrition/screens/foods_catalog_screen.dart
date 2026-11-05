import 'package:flutter/material.dart';

import '../../../core/widgets/app_loader.dart';
import '../../users/services/user_service.dart' show AuthException;
import '../models/food.dart';
import '../models/nutrition_enums.dart';
import '../repositories/food_repository.dart';
import '../widgets/nutrition_ui.dart';
import 'food_form_screen.dart';

/// Catalogue des aliments : consulter, rechercher, filtrer, ajouter, modifier,
/// supprimer.
class FoodsCatalogScreen extends StatefulWidget {
  const FoodsCatalogScreen({super.key});

  @override
  State<FoodsCatalogScreen> createState() => _FoodsCatalogScreenState();
}

class _FoodsCatalogScreenState extends State<FoodsCatalogScreen> {
  final _search = TextEditingController();
  FoodCategory? _category;
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
    setState(() => _loading = true);
    final foods = await FoodRepository.instance
        .getAll(search: _search.text, category: _category);
    if (mounted) {
      setState(() {
        _foods = foods;
        _loading = false;
      });
    }
  }

  Future<void> _openForm([Food? food]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => FoodFormScreen(food: food)),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(Food food) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'aliment'),
        content: Text('Supprimer « ${food.name} » ? Il sera retiré des repas '
            'où il apparaît.'),
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
      await FoodRepository.instance.delete(food.id!);
      _load();
    } on AuthException catch (e) {
      if (mounted) showNSnack(context, e.message, color: NColors.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NColors.bg,
      appBar: AppBar(
        title: const Text('Aliments'),
        backgroundColor: NColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: NColors.primary,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Aliment'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _search,
              onChanged: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _catChip(null, 'Tout'),
                ...FoodCategory.values.map((c) => _catChip(c, c.label)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: AppLoader(color: NColors.primary))
                : _foods.isEmpty
                    ? const Center(
                        child: Text('Aucun aliment.',
                            style: TextStyle(color: NColors.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                        itemCount: _foods.length,
                        itemBuilder: (_, i) => _foodCard(_foods[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _catChip(FoodCategory? c, String label) {
    final sel = _category == c;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        showCheckmark: false,
        selectedColor: NColors.primary,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
            color: sel ? Colors.white : NColors.textDark, fontSize: 12),
        onSelected: (_) {
          setState(() => _category = c);
          _load();
        },
      ),
    );
  }

  Widget _foodCard(Food f) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: NCard(
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(f.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: NColors.textDark)),
                        ),
                        if (f.isCustom)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                                color: NColors.lavender,
                                borderRadius: BorderRadius.circular(6)),
                            child: const Text('perso',
                                style: TextStyle(
                                    fontSize: 10, color: NColors.primary)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                        '${f.caloriesPer100g.round()} kcal · P ${f.proteinPer100g.round()} '
                        '/ G ${f.carbsPer100g.round()} / L ${f.fatsPer100g.round()} '
                        '(100 g)',
                        style: const TextStyle(
                            color: NColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                  onPressed: () => _openForm(f),
                  icon: const Icon(Icons.edit, size: 20, color: NColors.primary)),
              IconButton(
                  onPressed: () => _delete(f),
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: NColors.danger)),
            ],
          ),
        ),
      );
}
