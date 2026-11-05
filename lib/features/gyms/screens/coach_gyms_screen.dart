import 'package:flutter/material.dart';

import '../../../core/widgets/app_loader.dart'; // adapter si le nom diffère
import '../../users/services/user_service.dart' show AuthException;
import '../models/gym.dart';
import '../models/gym_coach.dart';
import '../models/gym_coach_request.dart';
import '../models/gym_status.dart';
import '../services/gym_coach_service.dart';
import '../services/gym_service.dart';
import '../widgets/coach_request_card.dart';

/// Côté coach : mes salles, salles disponibles, demandes (reçues et envoyées).
class CoachGymsScreen extends StatefulWidget {
  const CoachGymsScreen({super.key});

  @override
  State<CoachGymsScreen> createState() => _CoachGymsScreenState();
}

class _AvailableData {
  final List<Gym> gyms;
  final Map<int, String> links; // 'member' | 'pending'
  const _AvailableData(this.gyms, this.links);
}

class _CoachGymsScreenState extends State<CoachGymsScreen> {
  static const _violetDark = Color(0xFF4C378E);
  static const _pink = Color(0xFFD43DA7);
  static const _grayLight = Color(0xFFEFEDF5);
  static const _lilac = Color(0xFFE8D8FC);
  static const _textSecondary = Color(0xFF7A7390);

  late Future<List<GymCoach>> _mine;
  late Future<_AvailableData> _available;
  late Future<List<GymCoachRequest>> _requests;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _mine = GymCoachService.instance.getMyGyms();
    _available = _fetchAvailable();
    _requests = GymCoachService.instance.getRequestsForCoach();
  }

  Future<_AvailableData> _fetchAvailable() async {
    final gyms = await GymService.instance.getAll(status: GymStatus.open);
    final links = await GymCoachService.instance.getLinkByGym();
    return _AvailableData(gyms, links);
  }

  void _refresh() => setState(_load);

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: _violetDark, content: Text(m)),
    );
  }

  Future<void> _run(Future<void> Function() action, [String? ok]) async {
    try {
      await action();
      if (ok != null) _snack(ok);
    } on AuthException catch (e) {
      _snack(e.message);
    }
    _refresh();
  }

  Future<void> _apply(Gym g) async {
    final msg = await askRequestMessage(context, 'Postuler à ${g.name}');
    if (msg == null) return;
    await _run(
      () => GymCoachService.instance.applyToGym(gymId: g.id!, message: msg),
      'Candidature envoyée.',
    );
  }

  Future<void> _leave(GymCoach c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter cette salle ?'),
        content: Text('Vous ne ferez plus partie de « ${c.gymName} ».'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Rester')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitter',
                style: TextStyle(color: Color(0xFFD64545))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => GymCoachService.instance.leaveGym(c.id!));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _grayLight,
        appBar: AppBar(
          title: const Text('Mes salles (coach)'),
          backgroundColor: _violetDark,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Mes salles'),
              Tab(text: 'Disponibles'),
              Tab(text: 'Demandes'),
            ],
          ),
        ),
        body: TabBarView(children: [_mineTab(), _availableTab(), _requestsTab()]),
      ),
    );
  }

  Widget _empty(String text) => Center(
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textSecondary)),
      );

  Widget _mineTab() {
    return FutureBuilder<List<GymCoach>>(
      future: _mine,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: AppLoader());
        }
        if (snap.hasError) return Center(child: Text('${snap.error}'));
        final items = snap.data!;
        if (items.isEmpty) {
          return _empty('Vous n\'êtes dans aucune salle.\n'
              'Postulez depuis l\'onglet « Disponibles ».');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final c = items[i];
            return Card(
              color: Colors.white,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: _lilac,
                  child: Icon(Icons.fitness_center, color: _violetDark),
                ),
                title: Text(c.gymName ?? 'Salle',
                    style: const TextStyle(
                        color: _violetDark, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${c.gymCity ?? ''} · ${c.status.label}'
                  '${c.specialty.isEmpty ? '' : ' · ${c.specialty}'}',
                  style: const TextStyle(color: _textSecondary),
                ),
                trailing: IconButton(
                  tooltip: 'Quitter la salle',
                  icon: const Icon(Icons.logout, color: Color(0xFFD64545)),
                  onPressed: () => _leave(c),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _availableTab() {
    return FutureBuilder<_AvailableData>(
      future: _available,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: AppLoader());
        }
        if (snap.hasError) return Center(child: Text('${snap.error}'));
        final data = snap.data!;
        if (data.gyms.isEmpty) return _empty('Aucune salle ouverte.');
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: data.gyms.length,
          itemBuilder: (context, i) {
            final g = data.gyms[i];
            final link = data.links[g.id];
            Widget action;
            if (link == 'member') {
              action = const Text('Vous êtes coach ici',
                  style: TextStyle(
                      color: Color(0xFF2E9E6B), fontWeight: FontWeight.w600));
            } else if (link == 'pending') {
              action = const Text('Demande en attente',
                  style: TextStyle(
                      color: Color(0xFFE8920C), fontWeight: FontWeight.w600));
            } else {
              action = SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () => _apply(g),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Postuler comme coach'),
                ),
              );
            }
            return Card(
              color: Colors.white,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: _lilac,
                          child:
                              Icon(Icons.fitness_center, color: _violetDark),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.name,
                                  style: const TextStyle(
                                      color: _violetDark,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text('${g.city} · ${g.address}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      const TextStyle(color: _textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    action,
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _requestsTab() {
    return FutureBuilder<List<GymCoachRequest>>(
      future: _requests,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: AppLoader());
        }
        if (snap.hasError) return Center(child: Text('${snap.error}'));
        final items = snap.data!;
        if (items.isEmpty) return _empty('Aucune demande.');
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final r = items[i];
            return CoachRequestCard(
              request: r,
              asGym: false,
              onAccept: () => _run(
                  () => GymCoachService.instance.accept(r.id!),
                  'Vous avez rejoint la salle.'),
              onReject: () =>
                  _run(() => GymCoachService.instance.reject(r.id!)),
              onCancel: () =>
                  _run(() => GymCoachService.instance.cancel(r.id!)),
            );
          },
        );
      },
    );
  }
}
