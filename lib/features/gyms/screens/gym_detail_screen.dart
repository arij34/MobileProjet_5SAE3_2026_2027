import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/app_loader.dart'; // adapter si le nom diffère
import '../../users/services/user_service.dart' show AuthException;
import '../models/gym.dart';
import '../services/gym_coach_service.dart';
import '../services/gym_equipment_service.dart';
import '../services/gym_service.dart';
import '../widgets/gym_mini_map.dart';
import 'gym_coaches_screen.dart';
import 'gym_equipments_screen.dart';
import 'gym_form_screen.dart';

class GymDetailScreen extends StatefulWidget {
  final int gymId;
  const GymDetailScreen({super.key, required this.gymId});

  @override
  State<GymDetailScreen> createState() => _GymDetailScreenState();
}

class _GymDetailScreenState extends State<GymDetailScreen> {
  static const _violetDark = Color(0xFF4C378E);
  static const _pink = Color(0xFFD43DA7);
  static const _grayLight = Color(0xFFEFEDF5);
  static const _lilac = Color(0xFFE8D8FC);
  static const _violet = Color(0xFFA86BEE);
  static const _textSecondary = Color(0xFF7A7390);

  late Future<Gym?> _future;
  late Future<int> _equipCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = GymService.instance.getById(widget.gymId);
    _equipCount = GymEquipmentService.instance.countByGym(widget.gymId);
  }

  Future<void> _edit(Gym gym) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => GymFormScreen(gym: gym)),
    );
    if (saved == true) setState(_load);
  }

  Future<void> _openEquipments(Gym gym) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GymEquipmentsScreen(gym: gym)),
    );
    setState(_load); // le nombre d'équipements a pu changer
  }

  /// Ouvre l'application de cartes (ou le navigateur) vers la salle.
  Future<void> _openRoute(Gym gym) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1'
        '&destination=${gym.latitude},${gym.longitude}');
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: _violetDark,
          content: Text('Impossible d\'ouvrir l\'itinéraire.'),
        ),
      );
    }
  }

  Future<void> _delete(Gym gym) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la salle ?'),
        content: Text(
          '« ${gym.name} » et tous ses équipements seront supprimés.',
        ),
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
      await GymService.instance.delete(gym.id!);
      if (!mounted) return;
      Navigator.pop(context);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: _violetDark, content: Text(e.message)),
      );
    }
  }

  Widget _info(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _lilac,
              child: Icon(icon, size: 18, color: _violetDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: _textSecondary, fontSize: 12)),
                  Text(
                    value.isEmpty ? '—' : value,
                    style: const TextStyle(
                        color: _violetDark, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Gym?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: _grayLight,
            body: Center(child: AppLoader()),
          );
        }
        final gym = snap.data;
        if (gym == null) {
          return Scaffold(
            backgroundColor: _grayLight,
            appBar: AppBar(
              backgroundColor: _violetDark,
              foregroundColor: Colors.white,
            ),
            body: const Center(child: Text('Salle introuvable.')),
          );
        }
        final canEdit = GymService.instance.canEdit(gym);

        return Scaffold(
          backgroundColor: _grayLight,
          appBar: AppBar(
            title: Text(gym.name),
            backgroundColor: _violetDark,
            foregroundColor: Colors.white,
            actions: [
              if (canEdit) ...[
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _edit(gym),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _delete(gym),
                ),
              ],
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // En-tête avec dégradé standard
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_violetDark, _violet],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gym.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${gym.city} · ${gym.status.label}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${gym.priceMonthly.toStringAsFixed(0)} DT / mois',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Informations
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    _info(Icons.notes, 'Description', gym.description),
                    _info(Icons.place, 'Adresse', gym.address),
                    _info(Icons.phone, 'Téléphone', gym.phone),
                    _info(Icons.access_time, 'Horaires', gym.openingHours),
                    _info(Icons.people, 'Capacité', '${gym.capacity} personnes'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Localisation
              if (gym.hasLocation) ...[
                GymMiniMap(
                  point: LatLng(gym.latitude!, gym.longitude!),
                  height: 180,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => _openRoute(gym),
                    icon: const Icon(Icons.directions),
                    label: const Text('Itinéraire'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _violetDark,
                      side: const BorderSide(color: _violet),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ),
              ] else
                const Text('Localisation à définir',
                    style: TextStyle(color: _textSecondary)),
              const SizedBox(height: 16),

              // Accès aux équipements
              Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  leading: const CircleAvatar(
                    backgroundColor: _pink,
                    child: Icon(Icons.fitness_center, color: Colors.white),
                  ),
                  title: const Text('Équipements',
                      style: TextStyle(
                          color: _violetDark, fontWeight: FontWeight.bold)),
                  subtitle: FutureBuilder<int>(
                    future: _equipCount,
                    builder: (context, s) => Text(
                      s.hasData ? '${s.data} équipement(s)' : '...',
                      style: const TextStyle(color: _textSecondary),
                    ),
                  ),
                  trailing:
                      const Icon(Icons.chevron_right, color: _textSecondary),
                  onTap: () => _openEquipments(gym),
                ),
              ),

              // Coachs (responsable de la salle ou admin)
              if (GymCoachService.instance.canManage(gym)) ...[
                const SizedBox(height: 12),
                Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22)),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    leading: const CircleAvatar(
                      backgroundColor: _violet,
                      child: Icon(Icons.groups, color: Colors.white),
                    ),
                    title: const Text('Coachs',
                        style: TextStyle(
                            color: _violetDark, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Équipe, invitations et candidatures',
                        style: TextStyle(color: _textSecondary)),
                    trailing:
                        const Icon(Icons.chevron_right, color: _textSecondary),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => GymCoachesScreen(gym: gym)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}