import 'package:flutter/material.dart';

import '../../../core/widgets/app_loader.dart'; // adapter si le nom diffère
import '../../users/services/user_service.dart' show AuthException;
import '../models/equipment_category.dart';
import '../models/equipment_state.dart';
import '../models/gym.dart';
import '../models/gym_equipment.dart';
import '../services/gym_equipment_service.dart';
import 'equipment_form_screen.dart';

/// Liste des équipements d'une salle (ajout / modification / suppression
/// réservés à l'admin et au responsable de CETTE salle).
class GymEquipmentsScreen extends StatefulWidget {
  final Gym gym;
  const GymEquipmentsScreen({super.key, required this.gym});

  @override
  State<GymEquipmentsScreen> createState() => _GymEquipmentsScreenState();
}

class _GymEquipmentsScreenState extends State<GymEquipmentsScreen> {
  static const _violetDark = Color(0xFF4C378E);
  static const _pink = Color(0xFFD43DA7);
  static const _grayLight = Color(0xFFEFEDF5);
  static const _lilac = Color(0xFFE8D8FC);
  static const _textSecondary = Color(0xFF7A7390);

  late Future<List<GymEquipment>> _future;
  EquipmentCategory? _category;

  bool get _canManage => GymEquipmentService.instance.canManage(widget.gym);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = GymEquipmentService.instance
        .getByGym(widget.gym.id!, category: _category);
  }

  void _refresh() => setState(_load);

  Future<void> _openForm([GymEquipment? equipment]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EquipmentFormScreen(gym: widget.gym, equipment: equipment),
      ),
    );
    if (saved == true) _refresh();
  }

  Future<void> _delete(GymEquipment e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'équipement ?'),
        content: Text('« ${e.name} » sera supprimé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer',
                style: TextStyle(color: Color(0xFFD64545))),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await GymEquipmentService.instance.delete(e.id!);
      _refresh();
    } on AuthException catch (ex) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: _violetDark, content: Text(ex.message)),
      );
    }
  }

  IconData _iconFor(EquipmentCategory c) {
    switch (c) {
      case EquipmentCategory.cardio:
        return Icons.directions_run;
      case EquipmentCategory.strength:
        return Icons.fitness_center;
      case EquipmentCategory.groupClasses:
        return Icons.groups;
      case EquipmentCategory.functional:
        return Icons.sports_gymnastics;
      case EquipmentCategory.other:
        return Icons.category;
    }
  }

  Color _stateColor(EquipmentState s) {
    switch (s) {
      case EquipmentState.good:
        return const Color(0xFF2E9E6B);
      case EquipmentState.needsRepair:
        return const Color(0xFFE8920C);
      case EquipmentState.outOfOrder:
        return const Color(0xFFD64545);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _grayLight,
      appBar: AppBar(
        title: Text('Équipements · ${widget.gym.name}'),
        backgroundColor: _violetDark,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              backgroundColor: _pink,
              foregroundColor: Colors.white,
              onPressed: () => _openForm(),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          // Filtre par catégorie
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final c in EquipmentCategory.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(c.label),
                      selected: _category == c,
                      selectedColor: _lilac,
                      onSelected: (sel) {
                        _category = sel ? c : null;
                        _refresh();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<GymEquipment>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: AppLoader());
                }
                if (snap.hasError) {
                  return Center(child: Text('${snap.error}'));
                }
                final items = snap.data!;
                if (items.isEmpty) {
                  return const Center(
                    child: Text('Aucun équipement.',
                        style: TextStyle(color: _textSecondary)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final e = items[i];
                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: ListTile(
                        onTap: _canManage ? () => _openForm(e) : null,
                        leading: CircleAvatar(
                          backgroundColor: _lilac,
                          child: Icon(_iconFor(e.category),
                              color: _violetDark),
                        ),
                        title: Text(e.name,
                            style: const TextStyle(
                                color: _violetDark,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${e.category.label} · x${e.quantity}',
                          style: const TextStyle(color: _textSecondary),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              e.state.label,
                              style: TextStyle(
                                color: _stateColor(e.state),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            if (_canManage)
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Color(0xFFD64545)),
                                onPressed: () => _delete(e),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
