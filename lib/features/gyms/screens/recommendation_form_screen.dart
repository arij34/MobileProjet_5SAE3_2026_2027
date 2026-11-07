import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/session/session_manager.dart';
import '../../users/models/user_goal.dart';
import '../services/gym_recommendation_service.dart';
import '../services/gym_service.dart';
import '../services/user_location_service.dart';
import 'recommendation_result_screen.dart';

enum _LocationMode { gps, city }

/// Formulaire : localisation, budget et objectif sportif.
class RecommendationFormScreen extends StatefulWidget {
  const RecommendationFormScreen({super.key});

  @override
  State<RecommendationFormScreen> createState() =>
      _RecommendationFormScreenState();
}

class _RecommendationFormScreenState extends State<RecommendationFormScreen> {
  static const _violetDark = Color(0xFF4C378E);
  static const _pink = Color(0xFFD43DA7);
  static const _grayLight = Color(0xFFEFEDF5);
  static const _lilac = Color(0xFFE8D8FC);
  static const _violet = Color(0xFFA86BEE);
  static const _textSecondary = Color(0xFF7A7390);

  final _formKey = GlobalKey<FormState>();
  final _budget = TextEditingController();

  _LocationMode _mode = _LocationMode.city;
  LatLng? _pos;
  String? _city;
  List<String> _cities = [];
  bool _locating = false;
  late UserGoal _goal;

  @override
  void initState() {
    super.initState();
    // Objectif du profil pré-rempli (modifiable).
    _goal = SessionManager.instance.currentUser?.goal ?? UserGoal.gainMuscle;
    GymService.instance.getCities().then((c) {
      if (mounted) setState(() => _cities = c);
    });
    // Si la position est déjà autorisée, on la prend directement.
    UserLocationService.instance.tryGetSilently().then((p) {
      if (mounted && p != null) {
        setState(() {
          _pos = p;
          _mode = _LocationMode.gps;
        });
      }
    });
  }

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  Future<void> _selectMode(_LocationMode mode) async {
    setState(() => _mode = mode);
    if (mode == _LocationMode.gps && _pos == null) await _detect();
  }

  Future<void> _detect() async {
    setState(() => _locating = true);
    final res = await UserLocationService.instance.request();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (res.point != null) _pos = res.point;
    });
    if (res.error != null) _snack(res.error!);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: _violetDark, content: Text(message)),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_mode == _LocationMode.gps && _pos == null) {
      _snack('Position introuvable : autorisez-la ou choisissez une ville.');
      return;
    }
    final budget = double.parse(_budget.text.trim().replaceAll(',', '.'));
    final criteria = RecommendationCriteria(
      goal: _goal,
      maxBudget: budget,
      position: _mode == _LocationMode.gps ? _pos : null,
      city: _mode == _LocationMode.city ? _city : null,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecommendationResultScreen(criteria: criteria),
      ),
    );
  }

  Widget _section(String title, IconData icon) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: _violet),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: _violetDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _grayLight,
      appBar: AppBar(
        title: const Text('Recommandation IA'),
        backgroundColor: _violetDark,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Dites-nous ce que vous cherchez : nous classons les salles '
              'selon votre profil et l\'IA vous explique son choix.',
              style: TextStyle(color: _textSecondary),
            ),

            // ----- Localisation -----
            _section('Où cherchez-vous ?', Icons.place),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  avatar: _locating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 16),
                  label: Text(_mode == _LocationMode.gps && _pos != null
                      ? 'Ma position (détectée)'
                      : 'Ma position'),
                  selected: _mode == _LocationMode.gps,
                  selectedColor: _lilac,
                  onSelected: _locating
                      ? null
                      : (_) => _selectMode(_LocationMode.gps),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.location_city, size: 16),
                  label: const Text('Une ville'),
                  selected: _mode == _LocationMode.city,
                  selectedColor: _lilac,
                  onSelected: (_) => _selectMode(_LocationMode.city),
                ),
              ],
            ),
            if (_mode == _LocationMode.gps && _pos == null && !_locating)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: _detect,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Détecter ma position'),
                  style: TextButton.styleFrom(foregroundColor: _violetDark),
                ),
              ),
            if (_mode == _LocationMode.city) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _city,
                decoration: _deco('Ville', Icons.location_city),
                items: _cities
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _city = v),
                validator: (v) => (_mode == _LocationMode.city && v == null)
                    ? 'Choisissez une ville'
                    : null,
              ),
              if (_cities.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 4),
                  child: Text('Aucune salle enregistrée pour le moment.',
                      style: TextStyle(color: _textSecondary, fontSize: 12)),
                ),
            ],

            // ----- Budget -----
            _section('Votre budget', Icons.payments),
            TextFormField(
              controller: _budget,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: _deco('Budget maximum (DT / mois)', Icons.payments),
              validator: (v) {
                final n = double.tryParse((v ?? '').trim().replaceAll(',', '.'));
                return (n == null || n <= 0) ? 'Montant supérieur à 0' : null;
              },
            ),

            // ----- Objectif -----
            _section('Votre objectif', Icons.flag),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final g in UserGoal.values)
                  ChoiceChip(
                    label: Text(GymRecommendationService.goalLabel(g)),
                    selected: _goal == g,
                    selectedColor: _lilac,
                    onSelected: (_) => setState(() => _goal = g),
                  ),
              ],
            ),

            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Trouver ma salle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
}
