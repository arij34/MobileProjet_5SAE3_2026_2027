import 'package:flutter/material.dart';

import '../../../core/session/permissions.dart';
import '../../../core/session/session_manager.dart';
import '../../../core/widgets/app_loader.dart'; // adapter si le nom diffère
import '../models/gym.dart';
import '../models/gym_status.dart';
import '../services/gym_service.dart';
import 'gym_detail_screen.dart';
import 'gym_form_screen.dart';
import 'membership_requests_screen.dart';

class GymsListScreen extends StatefulWidget {
  const GymsListScreen({super.key});

  @override
  State<GymsListScreen> createState() => _GymsListScreenState();
}

class _GymsListScreenState extends State<GymsListScreen> {
  // Palette MyGym
  static const _violetDark = Color(0xFF4C378E);
  static const _pink = Color(0xFFD43DA7);
  static const _grayLight = Color(0xFFEFEDF5);
  static const _lilac = Color(0xFFE8D8FC);
  static const _violet = Color(0xFFA86BEE);
  static const _textSecondary = Color(0xFF7A7390);

  final _searchCtrl = TextEditingController();
  late Future<List<Gym>> _future;
  late Future<List<String>> _citiesFuture;
  String? _city;
  bool _onlyMine = false;

  bool get _canManage => Permissions.currentCan(Permission.manageGyms);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _load() {
    _future = GymService.instance.getAll(
      search: _searchCtrl.text,
      city: _city,
      ownerId: _onlyMine ? SessionManager.instance.currentUser?.id : null,
    );
    _citiesFuture = GymService.instance.getCities();
  }

  void _refresh() => setState(_load);

  Future<void> _openForm() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const GymFormScreen()),
    );
    if (saved == true) _refresh();
  }

  Future<void> _openDetail(Gym gym) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GymDetailScreen(gymId: gym.id!)),
    );
    _refresh(); // la salle a pu être modifiée ou supprimée
  }

  Color _statusColor(GymStatus s) {
    switch (s) {
      case GymStatus.open:
        return const Color(0xFF2E9E6B);
      case GymStatus.pending:
        return const Color(0xFFE8920C);
      case GymStatus.closed:
        return const Color(0xFFD64545);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _grayLight,
      appBar: AppBar(
        title: const Text('Salles de sport'),
        backgroundColor: _violetDark,
        foregroundColor: Colors.white,
        actions: [
          if (Permissions.currentCan(Permission.manageMemberships))
            IconButton(
              tooltip: 'Demandes d\'adhésion',
              icon: const Icon(Icons.how_to_reg),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MembershipRequestsScreen()),
              ),
            ),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              backgroundColor: _pink,
              foregroundColor: Colors.white,
              onPressed: _openForm,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          // Recherche en direct (onChanged)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _refresh(),
              decoration: InputDecoration(
                hintText: 'Rechercher (nom, ville, description)...',
                prefixIcon: const Icon(Icons.search, color: _violet),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Filtres : "Mes salles" + villes
          FutureBuilder<List<String>>(
            future: _citiesFuture,
            builder: (context, snap) {
              final cities = snap.data ?? [];
              final chips = <Widget>[
                if (_canManage)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: const Text('Mes salles'),
                      selected: _onlyMine,
                      selectedColor: _lilac,
                      onSelected: (v) {
                        _onlyMine = v;
                        _refresh();
                      },
                    ),
                  ),
                for (final c in cities)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: _city == c,
                      selectedColor: _lilac,
                      onSelected: (sel) {
                        _city = sel ? c : null;
                        _refresh();
                      },
                    ),
                  ),
              ];
              if (chips.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: chips,
                ),
              );
            },
          ),

          // Liste des salles
          Expanded(
            child: FutureBuilder<List<Gym>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: AppLoader());
                }
                if (snap.hasError) {
                  return Center(child: Text('${snap.error}'));
                }
                final gyms = snap.data!;
                if (gyms.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucune salle trouvée.',
                      style: TextStyle(color: _textSecondary),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: gyms.length,
                  itemBuilder: (context, i) => _buildCard(gyms[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Gym g) {
    return Card(
      color: Colors.white,
      elevation: 3,
      shadowColor: _violet.withValues(alpha: 0.3),
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openDetail(g),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: _lilac,
                child: Icon(Icons.fitness_center, color: _violetDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      g.name,
                      style: const TextStyle(
                        color: _violetDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${g.city} · ${g.address}',
                      style: const TextStyle(color: _textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.circle,
                            size: 10, color: _statusColor(g.status)),
                        const SizedBox(width: 4),
                        Text(
                          g.status.label,
                          style: TextStyle(color: _statusColor(g.status)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    g.priceMonthly.toStringAsFixed(0),
                    style: const TextStyle(
                      color: _pink,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const Text('DT / mois',
                      style: TextStyle(color: _textSecondary, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
