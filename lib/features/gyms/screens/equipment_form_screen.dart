import 'package:flutter/material.dart';

import '../../users/services/user_service.dart' show AuthException;
import '../models/equipment_category.dart';
import '../models/equipment_state.dart';
import '../models/gym.dart';
import '../models/gym_equipment.dart';
import '../services/gym_equipment_service.dart';

/// Ajout (equipment == null) ou modification d'un équipement.
class EquipmentFormScreen extends StatefulWidget {
  final Gym gym;
  final GymEquipment? equipment;
  const EquipmentFormScreen({super.key, required this.gym, this.equipment});

  @override
  State<EquipmentFormScreen> createState() => _EquipmentFormScreenState();
}

class _EquipmentFormScreenState extends State<EquipmentFormScreen> {
  static const _violetDark = Color(0xFF4C378E);
  static const _pink = Color(0xFFD43DA7);
  static const _grayLight = Color(0xFFEFEDF5);
  static const _violet = Color(0xFFA86BEE);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late EquipmentCategory _category;
  late EquipmentState _state;
  bool _saving = false;

  bool get _isEdit => widget.equipment != null;

  @override
  void initState() {
    super.initState();
    final e = widget.equipment;
    _name = TextEditingController(text: e?.name ?? '');
    _quantity = TextEditingController(text: '${e?.quantity ?? 1}');
    _category = e?.category ?? EquipmentCategory.cardio;
    _state = e?.state ?? EquipmentState.good;
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _violet),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _violet, width: 2),
        ),
      );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final old = widget.equipment;
      final equipment = GymEquipment(
        id: old?.id,
        gymId: widget.gym.id!,
        name: _name.text,
        category: _category,
        quantity: int.parse(_quantity.text.trim()),
        state: _state,
        createdAt: old?.createdAt ?? DateTime.now(),
      );

      if (_isEdit) {
        await GymEquipmentService.instance.update(equipment);
      } else {
        await GymEquipmentService.instance.create(equipment);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Une erreur est survenue. Réessayez.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: _violetDark, content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return Scaffold(
      backgroundColor: _grayLight,
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier l\'équipement' : 'Nouvel équipement'),
        backgroundColor: _violetDark,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              decoration: _deco('Nom (ex : Tapis de course)', Icons.build),
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Minimum 2 caractères'
                  : null,
            ),
            gap,
            DropdownButtonFormField<EquipmentCategory>(
              value: _category,
              decoration: _deco('Catégorie', Icons.category),
              items: EquipmentCategory.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            gap,
            TextFormField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: _deco('Quantité', Icons.numbers),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                return (n == null || n < 1) ? 'Entier supérieur à 0' : null;
              },
            ),
            gap,
            DropdownButtonFormField<EquipmentState>(
              value: _state,
              decoration: _deco('État', Icons.health_and_safety),
              items: EquipmentState.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) => setState(() => _state = v ?? _state),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'Enregistrer' : 'Valider'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
