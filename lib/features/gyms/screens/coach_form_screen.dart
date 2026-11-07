import 'package:flutter/material.dart';

import '../../users/services/user_service.dart' show AuthException;
import '../models/coach_enums.dart';
import '../models/gym_coach.dart';
import '../services/gym_coach_service.dart';

/// Modification de la fiche d'un coach dans la salle.
class CoachFormScreen extends StatefulWidget {
  final GymCoach coach;
  const CoachFormScreen({super.key, required this.coach});

  @override
  State<CoachFormScreen> createState() => _CoachFormScreenState();
}

class _CoachFormScreenState extends State<CoachFormScreen> {
  static const _violetDark = Color(0xFF4C378E);
  static const _pink = Color(0xFFD43DA7);
  static const _grayLight = Color(0xFFEFEDF5);
  static const _violet = Color(0xFFA86BEE);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _specialty;
  late final TextEditingController _rate;
  late final TextEditingController _availability;
  late GymCoachStatus _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.coach;
    _specialty = TextEditingController(text: c.specialty);
    _rate = TextEditingController(text: c.hourlyRate.toStringAsFixed(0));
    _availability = TextEditingController(text: c.availability);
    _status = c.status;
  }

  @override
  void dispose() {
    _specialty.dispose();
    _rate.dispose();
    _availability.dispose();
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
      await GymCoachService.instance.updateCoach(widget.coach.copyWith(
        specialty: _specialty.text,
        hourlyRate: double.parse(_rate.text.trim().replaceAll(',', '.')),
        availability: _availability.text,
        status: _status,
      ));
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AuthException catch (e) {
      _error(e.message);
    } catch (_) {
      _error('Une erreur est survenue. Réessayez.');
    }
  }

  void _error(String m) {
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: _violetDark, content: Text(m)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return Scaffold(
      backgroundColor: _grayLight,
      appBar: AppBar(
        title: Text(widget.coach.coachName ?? 'Fiche du coach'),
        backgroundColor: _violetDark,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _specialty,
              decoration: _deco('Spécialité (ex : Musculation)', Icons.star),
            ),
            gap,
            TextFormField(
              controller: _rate,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _deco('Tarif par séance (DT)', Icons.payments),
              validator: (v) {
                final n = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                return (n == null || n < 0) ? 'Nombre positif attendu' : null;
              },
            ),
            gap,
            TextFormField(
              controller: _availability,
              maxLines: 2,
              decoration: _deco(
                  'Disponibilités (ex : Lun-Ven 17h-21h)', Icons.schedule),
            ),
            gap,
            DropdownButtonFormField<GymCoachStatus>(
              initialValue: _status,
              decoration: _deco('Statut', Icons.toggle_on),
              items: GymCoachStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                  .toList(),
              onChanged: (v) => setState(() => _status = v ?? _status),
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
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
