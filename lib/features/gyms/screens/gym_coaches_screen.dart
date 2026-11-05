import 'package:flutter/material.dart';

import '../../../core/widgets/app_loader.dart'; // adapter si le nom diffère
import '../../users/services/user_service.dart' show AuthException;
import '../models/gym.dart';
import '../models/gym_coach.dart';
import '../models/gym_coach_request.dart';
import '../services/gym_coach_service.dart';
import '../widgets/coach_request_card.dart';
import 'coach_form_screen.dart';
import 'coach_search_screen.dart';

/// Côté responsable : coachs de la salle + demandes (envoyées et reçues).
class GymCoachesScreen extends StatefulWidget {
  final Gym gym;
  const GymCoachesScreen({super.key, required this.gym});

  @override
  State<GymCoachesScreen> createState() => _GymCoachesScreenState();
}

class _GymCoachesScreenState extends State<GymCoachesScreen> {
  static const _violetDark = Color(0xFF4C378E);
  static const _pink = Color(0xFFD43DA7);
  static const _grayLight = Color(0xFFEFEDF5);
  static const _lilac = Color(0xFFE8D8FC);
  static const _textSecondary = Color(0xFF7A7390);

  late Future<List<GymCoach>> _coaches;
  late Future<List<GymCoachRequest>> _requests;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _coaches = GymCoachService.instance.getCoaches(widget.gym.id!);
    _requests = GymCoachService.instance.getRequestsForGym(widget.gym.id!);
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

  Future<void> _invite() async {
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CoachSearchScreen(gym: widget.gym)),
    );
    if (sent == true) {
      _snack('Invitation envoyée.');
      _refresh();
    }
  }

  Future<void> _edit(GymCoach c) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CoachFormScreen(coach: c)),
    );
    if (saved == true) _refresh();
  }

  Future<void> _remove(GymCoach c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer ce coach ?'),
        content: Text('« ${c.coachName} » ne fera plus partie de la salle.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer',
                style: TextStyle(color: Color(0xFFD64545))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => GymCoachService.instance.removeCoach(c.id!));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _grayLight,
        appBar: AppBar(
          title: Text('Coachs · ${widget.gym.name}'),
          backgroundColor: _violetDark,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [Tab(text: 'Mes coachs'), Tab(text: 'Demandes')],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: _pink,
          foregroundColor: Colors.white,
          onPressed: _invite,
          icon: const Icon(Icons.person_add),
          label: const Text('Inviter'),
        ),
        body: TabBarView(children: [_coachesTab(), _requestsTab()]),
      ),
    );
  }

  Widget _coachesTab() {
    return FutureBuilder<List<GymCoach>>(
      future: _coaches,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: AppLoader());
        }
        if (snap.hasError) return Center(child: Text('${snap.error}'));
        final items = snap.data!;
        if (items.isEmpty) {
          return const Center(
            child: Text('Aucun coach pour le moment.\nInvitez-en un !',
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSecondary)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final c = items[i];
            final color = c.isActive
                ? const Color(0xFF2E9E6B)
                : const Color(0xFFE8920C);
            return Card(
              color: Colors.white,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: ListTile(
                onTap: () => _edit(c),
                leading: const CircleAvatar(
                  backgroundColor: _lilac,
                  child: Icon(Icons.person, color: _violetDark),
                ),
                title: Text(c.coachName ?? 'Coach',
                    style: const TextStyle(
                        color: _violetDark, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${c.specialty.isEmpty ? 'Spécialité à définir' : c.specialty}'
                  ' · ${c.hourlyRate.toStringAsFixed(0)} DT/séance',
                  style: const TextStyle(color: _textSecondary),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(c.status.label,
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                    IconButton(
                      icon: const Icon(Icons.person_remove,
                          color: Color(0xFFD64545)),
                      onPressed: () => _remove(c),
                    ),
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
        if (items.isEmpty) {
          return const Center(
            child: Text('Aucune demande.',
                style: TextStyle(color: _textSecondary)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final r = items[i];
            return CoachRequestCard(
              request: r,
              asGym: true,
              onAccept: () => _run(
                  () => GymCoachService.instance.accept(r.id!),
                  'Coach ajouté à la salle.'),
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
