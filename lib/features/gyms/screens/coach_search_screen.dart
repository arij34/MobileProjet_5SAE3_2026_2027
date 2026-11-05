import 'package:flutter/material.dart';

import '../../../core/widgets/app_loader.dart'; // adapter si le nom diffère
import '../../users/services/user_service.dart' show AuthException;
import '../models/gym.dart';
import '../services/gym_coach_service.dart';
import '../widgets/coach_request_card.dart';

/// Recherche d'un coach à inviter. Renvoie true si une invitation est partie.
class CoachSearchScreen extends StatefulWidget {
  final Gym gym;
  const CoachSearchScreen({super.key, required this.gym});

  @override
  State<CoachSearchScreen> createState() => _CoachSearchScreenState();
}

class _CoachSearchScreenState extends State<CoachSearchScreen> {
  static const _violetDark = Color(0xFF4C378E);
  static const _pink = Color(0xFFD43DA7);
  static const _grayLight = Color(0xFFEFEDF5);
  static const _lilac = Color(0xFFE8D8FC);
  static const _violet = Color(0xFFA86BEE);
  static const _textSecondary = Color(0xFF7A7390);

  final _searchCtrl = TextEditingController();
  late Future<List<CoachCandidate>> _future;
  bool _sentAny = false;

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

  void _load() => _future = GymCoachService.instance
      .searchCoaches(widget.gym.id!, search: _searchCtrl.text);

  void _refresh() => setState(_load);

  Future<void> _invite(CoachCandidate c) async {
    final msg = await askRequestMessage(context, 'Inviter ${c.name}');
    if (msg == null) return;
    try {
      await GymCoachService.instance
          .invite(gymId: widget.gym.id!, coachId: c.id, message: msg);
      _sentAny = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            backgroundColor: _violetDark,
            content: Text('Invitation envoyée à ${c.name}.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: _violetDark, content: Text(e.message)),
      );
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _sentAny);
      },
      child: Scaffold(
        backgroundColor: _grayLight,
        appBar: AppBar(
          title: const Text('Inviter un coach'),
          backgroundColor: _violetDark,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => _refresh(),
                decoration: InputDecoration(
                  hintText: 'Rechercher un coach par nom...',
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
            Expanded(
              child: FutureBuilder<List<CoachCandidate>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: AppLoader());
                  }
                  if (snap.hasError) return Center(child: Text('${snap.error}'));
                  final items = snap.data!;
                  if (items.isEmpty) {
                    return const Center(
                      child: Text('Aucun coach disponible.',
                          style: TextStyle(color: _textSecondary)),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
                            child: Icon(Icons.person, color: _violetDark),
                          ),
                          title: Text(c.name,
                              style: const TextStyle(
                                  color: _violetDark,
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            c.gymCount == 0
                                ? 'Coach libre'
                                : 'Dans ${c.gymCount} salle(s)',
                            style: const TextStyle(color: _textSecondary),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _invite(c),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _pink,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Inviter'),
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
      ),
    );
  }
}
