import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../users/services/user_service.dart' show AuthException;
import '../models/gym.dart';
import '../models/gym_status.dart';
import '../services/geocoding_service.dart';
import '../services/gym_service.dart';
import '../widgets/gym_mini_map.dart';
import 'map_picker_screen.dart';

/// Création (gym == null) ou modification (gym != null) d'une salle.
class GymFormScreen extends StatefulWidget {
  final Gym? gym;
  const GymFormScreen({super.key, this.gym});

  @override
  State<GymFormScreen> createState() => _GymFormScreenState();
}

class _GymFormScreenState extends State<GymFormScreen> {
  static const _violetDark = Color(0xFF4C378E);
  static const _pink = Color(0xFFD43DA7);
  static const _grayLight = Color(0xFFEFEDF5);
  static const _violet = Color(0xFFA86BEE);
  static const _textSecondary = Color(0xFF7A7390);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _phone;
  late final TextEditingController _hours;
  late final TextEditingController _capacity;
  late final TextEditingController _price;
  late GymStatus _status;
  bool _saving = false;

  // Localisation choisie sur la carte
  double? _lat;
  double? _lng;
  String? _locationError;

  bool get _isEdit => widget.gym != null;

  @override
  void initState() {
    super.initState();
    final g = widget.gym;
    _name = TextEditingController(text: g?.name ?? '');
    _description = TextEditingController(text: g?.description ?? '');
    _address = TextEditingController(text: g?.address ?? '');
    _city = TextEditingController(text: g?.city ?? '');
    _phone = TextEditingController(text: g?.phone ?? '');
    _hours = TextEditingController(text: g?.openingHours ?? '');
    _capacity = TextEditingController(text: g == null ? '' : '${g.capacity}');
    _price = TextEditingController(text: g == null ? '' : '${g.priceMonthly}');
    _status = g?.status ?? GymStatus.open;
    _lat = g?.latitude;
    _lng = g?.longitude;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _address,
      _city,
      _phone,
      _hours,
      _capacity,
      _price,
    ]) {
      c.dispose();
    }
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

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;

  String? _positiveNumber(String? v) {
    if (v == null || v.trim().isEmpty) return 'Champ obligatoire';
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null || n < 0) return 'Nombre positif attendu';
    return null;
  }

  /// Ouvre la carte ; remplit adresse et ville avec le lieu choisi.
  Future<void> _pickLocation() async {
    final result = await Navigator.push<GeoPlace>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initial:
              (_lat != null && _lng != null) ? LatLng(_lat!, _lng!) : null,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _lat = result.latitude;
      _lng = result.longitude;
      _locationError = null;
      if (result.address.isNotEmpty) _address.text = result.address;
      if (result.city.isNotEmpty) _city.text = result.city;
    });
  }

  Widget _locationSection() {
    final hasPoint = _lat != null && _lng != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasPoint)
          GymMiniMap(point: LatLng(_lat!, _lng!), onTap: _pickLocation)
        else
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: _pickLocation,
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: _locationError == null
                    ? null
                    : Border.all(color: const Color(0xFFD64545)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_location_alt, size: 40, color: _violet),
                  SizedBox(height: 8),
                  Text(
                    'Choisir la localisation sur la carte',
                    style: TextStyle(
                        color: _violetDark, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        if (hasPoint)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _pickLocation,
              icon: const Icon(Icons.edit_location_alt, size: 18),
              label: const Text('Modifier sur la carte'),
              style: TextButton.styleFrom(foregroundColor: _violetDark),
            ),
          ),
        if (_locationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(_locationError!,
                style: const TextStyle(color: Color(0xFFD64545), fontSize: 12)),
          ),
      ],
    );
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState!.validate();
    // La localisation est obligatoire à la création d'une salle.
    if (!_isEdit && _lat == null) {
      setState(() => _locationError = 'Choisissez la localisation sur la carte.');
      return;
    }
    if (!formOk) return;
    setState(() => _saving = true);

    try {
      final old = widget.gym;
      final gym = Gym(
        id: old?.id,
        ownerId: old?.ownerId ?? 0, // remplacé par le service à la création
        name: _name.text,
        description: _description.text,
        address: _address.text,
        city: _city.text,
        latitude: _lat,
        longitude: _lng,
        phone: _phone.text,
        openingHours: _hours.text,
        capacity: int.tryParse(_capacity.text.trim()) ?? 0,
        priceMonthly: double.tryParse(_price.text.replaceAll(',', '.')) ?? 0,
        status: _status,
        photoPath: old?.photoPath, // ne pas effacer la photo à la modification
        createdAt: old?.createdAt ?? DateTime.now(),
      );

      if (_isEdit) {
        await GymService.instance.update(gym);
      } else {
        await GymService.instance.create(gym);
      }
      if (!mounted) return;
      Navigator.pop(context, true); // true => la liste se rafraîchit
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
        title: Text(_isEdit ? 'Modifier la salle' : 'Nouvelle salle'),
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
              decoration: _deco('Nom de la salle', Icons.fitness_center),
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'Minimum 3 caractères'
                  : null,
            ),
            gap,
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: _deco('Description', Icons.notes),
            ),
            gap,
            _locationSection(),
            gap,
            TextFormField(
              controller: _address,
              decoration: _deco('Adresse', Icons.place),
              validator: _required,
            ),
            gap,
            TextFormField(
              controller: _city,
              decoration: _deco('Ville', Icons.location_city),
              validator: _required,
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Remplies automatiquement depuis la carte, modifiables si besoin.',
                style: TextStyle(color: _textSecondary, fontSize: 12),
              ),
            ),
            gap,
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _deco('Téléphone', Icons.phone),
              validator: (v) => (v != null &&
                      v.trim().isNotEmpty &&
                      !RegExp(r'^[0-9+ ]{8,15}$').hasMatch(v.trim()))
                  ? 'Numéro invalide'
                  : null,
            ),
            gap,
            TextFormField(
              controller: _hours,
              decoration:
                  _deco('Horaires (ex : 06:00 - 22:00)', Icons.access_time),
            ),
            gap,
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _capacity,
                    keyboardType: TextInputType.number,
                    decoration: _deco('Capacité', Icons.people),
                    validator: _positiveNumber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _deco('Prix / mois (DT)', Icons.payments),
                    validator: _positiveNumber,
                  ),
                ),
              ],
            ),
            gap,
            DropdownButtonFormField<GymStatus>(
              initialValue: _status,
              decoration: _deco('Statut', Icons.toggle_on),
              items: GymStatus.values
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
