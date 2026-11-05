import 'package:flutter/material.dart';

import '../../../core/widgets/app_loader.dart'; // adapter si le nom diffère
import '../models/gym.dart';
import '../models/membership_status.dart';
import '../services/geo_utils.dart';
import '../services/gym_recommendation_service.dart';
import '../services/membership_service.dart';
import 'gym_apply_sheet.dart';
import 'gym_detail_screen.dart';
import 'my_memberships_screen.dart';

/// Résultat de la recommandation : meilleure salle + 2 alternatives.
class RecommendationResultScreen extends StatefulWidget {
  final RecommendationCriteria criteria;
  const RecommendationResultScreen({super.key, required this.criteria});

  @override
  State<RecommendationResultScreen> createState() =>
      _RecommendationResultScreenState();
}

class _RecommendationResultScreenState
    extends State<RecommendationResultScreen> {
  static const _violetDark = Color(0xFF4C378E);
  static const _pink = Color(0xFFD43DA7);
  static const _grayLight = Color(0xFFEFEDF5);
  static const _lilac = Color(0xFFE8D8FC);
  static const _violet = Color(0xFFA86BEE);
  static const _textSecondary = Color(0xFF7A7390);
  static const _orange = Color(0xFFE8920C);

  late Future<RecommendationResult> _future;
  Map<int, MembershipStatus> _statuses = {};

  @override
  void initState() {
    super.initState();
    // Le calcul (et l'appel à l'IA) n'est fait qu'une fois.
    _future = GymRecommendationService.instance.recommend(widget.criteria);
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    final s = await MembershipService.instance.getStatusByGym();
    if (mounted) setState(() => _statuses = s);
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
      _loadStatuses();
    }
  }

  void _openDetail(Gym gym) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GymDetailScreen(gymId: gym.id!)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _grayLight,
      appBar: AppBar(
        title: const Text('Votre recommandation'),
        backgroundColor: _violetDark,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<RecommendationResult>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppLoader(),
                  SizedBox(height: 16),
                  Text('Analyse des salles en cours...',
                      style: TextStyle(color: _textSecondary)),
                ],
              ),
            );
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('${snap.error}', textAlign: TextAlign.center),
              ),
            );
          }
          return _content(snap.data!);
        },
      ),
    );
  }

  Widget _content(RecommendationResult result) {
    if (result.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucune salle ouverte pour le moment.',
            style: TextStyle(color: _textSecondary),
          ),
        ),
      );
    }

    final c = widget.criteria;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Rappel du profil
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _tag(Icons.flag, GymRecommendationService.goalLabel(c.goal)),
            _tag(Icons.payments, '${c.maxBudget.toStringAsFixed(0)} DT / mois'),
            _tag(Icons.place, c.position != null ? 'Près de moi' : (c.city ?? '')),
          ],
        ),
        const SizedBox(height: 12),

        // Origine de l'analyse
        Row(
          children: [
            Icon(result.aiUsed ? Icons.auto_awesome : Icons.calculate,
                size: 16, color: _violet),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                result.aiUsed
                    ? 'Explications rédigées par l\'IA'
                    : 'IA indisponible : classement calculé sur votre appareil',
                style: const TextStyle(color: _textSecondary, fontSize: 12),
              ),
            ),
          ],
        ),
        if (result.noneWithinBudget)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Aucune salle ne rentre dans votre budget. Voici les plus '
              'proches de vos critères.',
              style: TextStyle(color: _orange),
            ),
          ),
        if (result.summary != null) ...[
          const SizedBox(height: 12),
          Text(result.summary!,
              style: const TextStyle(
                  color: _violetDark, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 16),

        _bestCard(result.items.first),
        if (result.items.length > 1) ...[
          const SizedBox(height: 18),
          const Text('Autres options',
              style: TextStyle(
                  color: _violetDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 10),
          for (final r in result.items.skip(1)) _otherCard(r),
        ],
      ],
    );
  }

  Widget _tag(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _lilac,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _violetDark),
            const SizedBox(width: 5),
            Text(text,
                style: const TextStyle(color: _violetDark, fontSize: 12)),
          ],
        ),
      );

  /// Bouton Postuler, ou statut si l'adhérent a déjà une demande/adhésion.
  Widget _applyAction(GymRecommendation r, {required bool onDark}) {
    final status = _statuses[r.gym.id];
    if (status == MembershipStatus.active) {
      return _infoPill('Vous êtes déjà adhérent', const Color(0xFF2E9E6B),
          onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyMembershipsScreen()),
              ));
    }
    if (status == MembershipStatus.pending) {
      return _infoPill('Demande en attente', _orange);
    }
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: () => _apply(r.gym),
        style: ElevatedButton.styleFrom(
          backgroundColor: onDark ? Colors.white : _pink,
          foregroundColor: onDark ? _pink : Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Postuler'),
      ),
    );
  }

  Widget _infoPill(String text, Color color, {VoidCallback? onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _bestCard(GymRecommendation r) {
    final g = r.gym;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_violetDark, _violet],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('MEILLEUR CHOIX',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Text('${r.fitPercent} %',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              const Text('adapté',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          Text(g.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            '${g.city} · ${g.priceMonthly.toStringAsFixed(0)} DT / mois'
            '${r.distanceKm != null ? ' · à ${GeoUtils.format(r.distanceKm!)}' : ''}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Text(r.explanation,
              style: const TextStyle(color: Colors.white, height: 1.35)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _applyAction(r, onDark: true)),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => _openDetail(g),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Voir la salle'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _otherCard(GymRecommendation r) {
    final g = r.gym;
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
                Expanded(
                  child: Text(g.name,
                      style: const TextStyle(
                          color: _violetDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _lilac,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${r.fitPercent} %',
                      style: const TextStyle(
                          color: _violetDark, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${g.city} · ${g.priceMonthly.toStringAsFixed(0)} DT / mois'
              '${r.distanceKm != null ? ' · à ${GeoUtils.format(r.distanceKm!)}' : ''}'
              '${r.withinBudget ? '' : ' · hors budget'}',
              style: TextStyle(
                  color: r.withinBudget ? _textSecondary : _orange),
            ),
            const SizedBox(height: 10),
            Text(r.explanation,
                style: const TextStyle(color: _violetDark, height: 1.35)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _applyAction(r, onDark: false)),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => _openDetail(g),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _violetDark,
                    side: const BorderSide(color: _violet),
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Voir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
