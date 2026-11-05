import 'package:flutter/material.dart';

import '../../../core/widgets/app_loader.dart'; // adapter si le nom diffère
import '../../users/services/user_service.dart' show AuthException;
import '../models/gym_membership.dart';
import '../models/membership_status.dart';
import '../services/membership_service.dart';
import '../widgets/membership_status_chip.dart';
import 'membership_card_screen.dart';

/// Les demandes et adhésions de l'adhérent connecté.
class MyMembershipsScreen extends StatefulWidget {
  const MyMembershipsScreen({super.key});

  @override
  State<MyMembershipsScreen> createState() => _MyMembershipsScreenState();
}

class _MyMembershipsScreenState extends State<MyMembershipsScreen> {
  static const _violetDark = Color(0xFF4C378E);
  static const _pink = Color(0xFFD43DA7);
  static const _grayLight = Color(0xFFEFEDF5);
  static const _lilac = Color(0xFFE8D8FC);
  static const _textSecondary = Color(0xFF7A7390);

  late Future<List<GymMembership>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = MembershipService.instance.getMine();

  void _refresh() => setState(_load);

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: _violetDark, content: Text(message)),
    );
  }

  Future<void> _cancel(GymMembership m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la demande ?'),
        content: Text('Votre demande pour « ${m.gymName} » sera annulée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Garder'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Annuler la demande',
                style: TextStyle(color: Color(0xFFD64545))),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await MembershipService.instance.cancel(m.id!);
      _refresh();
    } on AuthException catch (e) {
      _snack(e.message);
      _refresh();
    }
  }

  Future<void> _openCard(GymMembership m) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MembershipCardScreen(membership: m)),
    );
  }

  String _dt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _grayLight,
      appBar: AppBar(
        title: const Text('Mes adhésions'),
        backgroundColor: _violetDark,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<GymMembership>>(
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.card_membership,
                        size: 56, color: _textSecondary),
                    const SizedBox(height: 12),
                    const Text('Aucune adhésion pour le moment.',
                        style: TextStyle(color: _textSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _pink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Parcourir les salles'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) => _buildCard(items[i]),
          );
        },
      ),
    );
  }

  Widget _buildCard(GymMembership m) {
    final active = m.isActive;
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
                  child: Icon(Icons.fitness_center, color: _violetDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.gymName ?? 'Salle',
                          style: const TextStyle(
                              color: _violetDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text(m.gymCity ?? '',
                          style: const TextStyle(color: _textSecondary)),
                    ],
                  ),
                ),
                MembershipStatusChip(status: m.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Formule ${m.formulaLabel} · ${_dt(m.priceTotal)} DT',
              style: const TextStyle(color: _violetDark),
            ),
            if (m.status == MembershipStatus.active && m.endDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Valable jusqu\'au ${GymMembership.formatDate(m.endDate!)}',
                  style: const TextStyle(color: _textSecondary),
                ),
              ),
            if (m.status == MembershipStatus.pending)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('En attente de validation par le responsable.',
                    style: TextStyle(color: _textSecondary, fontSize: 12)),
              ),
            if (active || m.status == MembershipStatus.pending) ...[
              const SizedBox(height: 12),
              if (active)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () => _openCard(m),
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Voir ma carte'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _pink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () => _cancel(m),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD64545),
                      side: const BorderSide(color: Color(0xFFD64545)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Annuler la demande'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
