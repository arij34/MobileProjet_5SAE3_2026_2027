import 'package:flutter/material.dart';

import '../../../core/widgets/app_loader.dart'; // adapter si le nom diffère
import '../../users/services/user_service.dart' show AuthException;
import '../models/gym_membership.dart';
import '../models/membership_status.dart';
import '../services/membership_service.dart';
import '../widgets/membership_status_chip.dart';

/// Demandes d'adhésion des salles du responsable (toutes pour l'admin).
class MembershipRequestsScreen extends StatefulWidget {
  const MembershipRequestsScreen({super.key});

  @override
  State<MembershipRequestsScreen> createState() =>
      _MembershipRequestsScreenState();
}

class _MembershipRequestsScreenState extends State<MembershipRequestsScreen> {
  static const _violetDark = Color(0xFF4C378E);
  static const _pink = Color(0xFFD43DA7);
  static const _grayLight = Color(0xFFEFEDF5);
  static const _lilac = Color(0xFFE8D8FC);
  static const _textSecondary = Color(0xFF7A7390);

  // null = toutes
  static const List<MembershipStatus?> _filters = [
    MembershipStatus.pending,
    MembershipStatus.active,
    null,
  ];

  MembershipStatus? _filter = MembershipStatus.pending;
  late Future<List<GymMembership>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _future = MembershipService.instance.getRequests(status: _filter);

  void _refresh() => setState(_load);

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: _violetDark, content: Text(message)),
    );
  }

  String _filterLabel(MembershipStatus? s) => switch (s) {
        MembershipStatus.pending => 'En attente',
        MembershipStatus.active => 'Actives',
        _ => 'Toutes',
      };

  Future<void> _accept(GymMembership m) async {
    try {
      await MembershipService.instance.accept(m.id!);
      _snack('Adhésion activée : la carte QR est disponible pour l\'adhérent.');
    } on AuthException catch (e) {
      _snack(e.message);
    }
    _refresh();
  }

  Future<void> _reject(GymMembership m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser la demande ?'),
        content: Text('La demande de ${m.memberName} sera refusée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Refuser',
                style: TextStyle(color: Color(0xFFD64545))),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await MembershipService.instance.reject(m.id!);
    } on AuthException catch (e) {
      _snack(e.message);
    }
    _refresh();
  }

  String _dt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _grayLight,
      appBar: AppBar(
        title: const Text('Demandes d\'adhésion'),
        backgroundColor: _violetDark,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final f in _filters)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(_filterLabel(f)),
                      selected: _filter == f,
                      selectedColor: _lilac,
                      onSelected: (_) {
                        _filter = f;
                        _refresh();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<GymMembership>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: AppLoader());
                }
                if (snap.hasError) {
                  return Center(child: Text('${snap.error}'));
                }
                final items = snap.data!;
                if (items.isEmpty) {
                  return const Center(
                    child: Text('Aucune demande.',
                        style: TextStyle(color: _textSecondary)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _buildCard(items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(GymMembership m) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: _lilac,
                  child: Icon(Icons.person, color: _violetDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.memberName ?? 'Adhérent',
                          style: const TextStyle(
                              color: _violetDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text('${m.gymName ?? ''} · ${m.gymCity ?? ''}',
                          style: const TextStyle(color: _textSecondary)),
                    ],
                  ),
                ),
                MembershipStatusChip(status: m.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Formule ${m.formulaLabel} · ${_dt(m.priceTotal)} DT · '
              'demandée le ${GymMembership.formatDate(m.createdAt)}',
              style: const TextStyle(color: _violetDark, fontSize: 13),
            ),
            if (m.status == MembershipStatus.active && m.endDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Valable jusqu\'au ${GymMembership.formatDate(m.endDate!)}',
                  style: const TextStyle(color: _textSecondary, fontSize: 12),
                ),
              ),
            if (m.status == MembershipStatus.pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reject(m),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD64545),
                        side: const BorderSide(color: Color(0xFFD64545)),
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Refuser'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _accept(m),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pink,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Accepter'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
