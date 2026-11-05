import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/app_loader.dart'; // adapter si le nom diffère
import '../models/gym.dart';
import '../models/gym_status.dart';
import '../models/membership_status.dart';
import '../services/geo_utils.dart';
import '../services/gym_service.dart';
import '../services/membership_service.dart';
import '../services/user_location_service.dart';
import 'gym_apply_sheet.dart';
import 'gym_detail_screen.dart';
import 'my_memberships_screen.dart';
import 'recommendation_form_screen.dart';

class _CatalogItem {
  final Gym gym;
  final double? distanceKm;
  const _CatalogItem(this.gym, this.distanceKm);
}

class _CatalogData {
  final List<_CatalogItem> items;
  final Map<int, MembershipStatus> statuses;
  const _CatalogData(this.items, this.statuses);
}

/// Catalogue des salles pour l'adhérent : nom, lieu, prix, distance,
/// bouton Postuler et accès à la recommandation par l'IA.
class GymCatalogScreen extends StatefulWidget {
  const GymCatalogScreen({super.key});

  @override
  State<GymCatalogScreen> createState() => _GymCatalogScreenState();
}

class _GymCatalogScreenState extends State<GymCatalogScreen> {
  static const _violetDark = Color(0xFF4C378E);
  static const _pink = Color(0xFFD43DA7);
  static const _grayLight = Color(0xFFEFEDF5);
  static const _lilac = Color(0xFFE8D8FC);
  static const _violet = Color(0xFFA86BEE);
  static const _textSecondary = Color(0xFF7A7390);

  final _searchCtrl = TextEditingController();
  late Future<_CatalogData> _future;
  late Future<List<String>> _citiesFuture;
  String? _city;

  LatLng? _myPos;
  bool _useLocation = false; // tri par distance actif
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _citiesFuture = GymService.instance.getCities();
    _load();
    _initLocation();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _load() => _future = _fetch();

  void _refresh() => setState(_load);

  /// Si la permission est déjà accordée, on utilise la position sans rien demander.
  Future<void> _initLocation() async {
    final p = await UserLocationService.instance.tryGetSilently();
    if (!mounted || p == null) return;
    setState(() {
      _myPos = p;
      _useLocation = true;
      _load();
    });
  }

  Future<_CatalogData> _fetch() async {
    final gyms = await GymService.instance.getAll(
      search: _searchCtrl.text,
      city: _city,
      status: GymStatus.open, // seules les salles ouvertes acceptent des demandes
    );
    final statuses = await MembershipService.instance.getStatusByGym();

    final pos = _useLocation ? _myPos : null;
    final items = gyms.map((g) {
      final d = (pos != null && g.hasLocation)
          ? GeoUtils.distanceKm(
              pos.latitude, pos.longitude, g.latitude!, g.longitude!)
          : null;
      return _CatalogItem(g, d);
    }).toList();

    if (pos != null) {
      // Les plus proches d'abord ; les salles sans coordonnées à la fin.
      items.sort((a, b) {
        if (a.distanceKm == null && b.distanceKm == null) return 0;
        if (a.distanceKm == null) return 1;
        if (b.distanceKm == null) return -1;
        return a.distanceKm!.compareTo(b.distanceKm!);
      });
    }
    return _CatalogData(items, statuses);
  }

  Future<void> _toggleLocation() async {
    if (_useLocation) {
      setState(() {
        _useLocation = false;
        _load();
      });
      return;
    }
    setState(() => _locating = true);
    final res = await UserLocationService.instance.request();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (res.point != null) {
        _myPos = res.point;
        _useLocation = true;
        _load();
      }
    });
    if (res.error != null) _snack(res.error!);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: _violetDark, content: Text(message)),
    );
  }

  Future<void> _apply(Gym gym) async {
    final ok = await showApplySheet(context, gym);
    if (!mounted) return;
    if (ok) {
      _snack('Demande envoyée. Le responsable va l\'examiner.');
      _refresh();
    }
  }

  Future<void> _openDetail(Gym gym) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GymDetailScreen(gymId: gym.id!)),
    );
    if (mounted) _refresh();
  }

  Future<void> _openMemberships() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyMembershipsScreen()),
    );
    if (mounted) _refresh();
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
          IconButton(
            tooltip: 'Mes adhésions',
            icon: const Icon(Icons.card_membership),
            onPressed: _openMemberships,
          ),
        ],
      ),
      body: Column(
        children: [
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

          // Filtres : "Près de moi" + villes
          FutureBuilder<List<String>>(
            future: _citiesFuture,
            builder: (context, snap) {
              final cities = snap.data ?? [];
              return SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        avatar: _locating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.near_me, size: 16),
                        label: const Text('Près de moi'),
                        selected: _useLocation,
                        selectedColor: _lilac,
                        onSelected: _locating ? null : (_) => _toggleLocation(),
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
                  ],
                ),
              );
            },
          ),

          Expanded(
            child: FutureBuilder<_CatalogData>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: AppLoader());
                }
                if (snap.hasError) {
                  return Center(child: Text('${snap.error}'));
                }
                final data = snap.data!;
                if (data.items.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _aiBanner(),
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text('Aucune salle trouvée.',
                              style: TextStyle(color: _textSecondary)),
                        ),
                      ),
                    ],
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: data.items.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) return _aiBanner();
                    final item = data.items[i - 1];
                    return _buildCard(item, data.statuses[item.gym.id]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RecommendationFormScreen()),
        ).then((_) {
          if (mounted) _refresh();
        }),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_violetDark, _violet],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 34),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trouvez la salle idéale',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Recommandation par IA selon votre objectif, '
                      'votre budget et votre localisation.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusAction(Gym gym, MembershipStatus? status) {
    if (status == MembershipStatus.active) {
      return Row(
        children: [
          const Icon(Icons.verified, color: Color(0xFF2E9E6B), size: 20),
          const SizedBox(width: 6),
          const Expanded(
            child: Text('Vous êtes adhérent',
                style: TextStyle(
                    color: Color(0xFF2E9E6B), fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: _openMemberships,
            child: const Text('Ma carte'),
          ),
        ],
      );
    }
    if (status == MembershipStatus.pending) {
      return const Row(
        children: [
          Icon(Icons.hourglass_top, color: Color(0xFFE8920C), size: 20),
          SizedBox(width: 6),
          Text('Demande en attente',
              style: TextStyle(
                  color: Color(0xFFE8920C), fontWeight: FontWeight.w600)),
        ],
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: () => _apply(gym),
        style: ElevatedButton.styleFrom(
          backgroundColor: _pink,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Postuler'),
      ),
    );
  }

  Widget _buildCard(_CatalogItem item, MembershipStatus? status) {
    final g = item.gym;
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
          child: Column(
            children: [
              Row(
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
                        Row(
                          children: [
                            const Icon(Icons.place,
                                size: 14, color: _textSecondary),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                '${g.city} · ${g.address}',
                                style: const TextStyle(color: _textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (item.distanceKm != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _lilac,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.near_me,
                                    size: 12, color: _violetDark),
                                const SizedBox(width: 4),
                                Text(
                                  'à ${GeoUtils.format(item.distanceKm!)}',
                                  style: const TextStyle(
                                      color: _violetDark, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                          style:
                              TextStyle(color: _textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _statusAction(g, status),
            ],
          ),
        ),
      ),
    );
  }
}
