import 'package:flutter/material.dart';

import '../../../core/widgets/app_loader.dart';
import '../../gyms/models/gym.dart';
import '../services/activity_ai_service.dart';
import '../services/activity_service.dart';
import 'activity_form_screen.dart';
import 'activity_ui.dart';

/// Assistant IA : analyse les activités de la salle et propose des idées.
/// Rien n'est enregistré sans confirmation explicite du responsable.
class AiAssistantScreen extends StatefulWidget {
  final Gym gym;
  const AiAssistantScreen({super.key, required this.gym});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  bool _loading = false;
  bool _analyzed = false;
  String? _error;
  List<ActivityProposal> _proposals = [];

  Future<void> _analyze() async {
    setState(() {
      _loading = true;
      _error = null;
      _analyzed = true;
    });
    try {
      final existing =
          await ActivityService.instance.getForGym(widget.gym.id!);
      final result = await ActivityAiService.instance.suggest(existing);
      if (!mounted) return;
      setState(() {
        _proposals = result.proposals;
        _error = result.error;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept(ActivityProposal p) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityFormScreen(
          gymId: widget.gym.id!,
          activity: p.toActivity(widget.gym.id!),
        ),
      ),
    );
    if (created == true && mounted) {
      setState(() => _proposals.remove(p));
      showASnack(context, 'Activité ajoutée depuis la proposition IA.',
          color: AColors.green);
    }
  }

  void _refuse(ActivityProposal p) {
    setState(() => _proposals.remove(p));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AColors.grayLight,
      appBar: AppBar(
        title: const Text('Assistant IA'),
        backgroundColor: AColors.violetDark,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _intro(),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _intro() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        color: AColors.violetDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Idées pour « ${widget.gym.name} »',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'L\'IA analyse vos activités existantes et suggère des nouveautés. '
              'Vous gardez le contrôle : rien n\'est ajouté sans votre '
              'confirmation.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _analyze,
                icon: const Icon(Icons.psychology),
                label: Text(_analyzed ? 'Relancer l\'analyse'
                    : 'Analyser mes activités'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AColors.pink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _content() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLoader(),
            SizedBox(height: 16),
            Text('Gemini analyse vos activités...',
                style: TextStyle(color: AColors.textSecondary)),
          ],
        ),
      );
    }
    if (!_analyzed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'Touchez « Analyser mes activités » pour obtenir des suggestions '
            'personnalisées.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AColors.textSecondary),
          ),
        ),
      );
    }
    if (_error != null && _proposals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline,
                  color: AColors.textSecondary, size: 40),
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AColors.textSecondary)),
            ],
          ),
        ),
      );
    }
    if (_proposals.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text('Toutes les propositions ont été traitées.',
              style: TextStyle(color: AColors.textSecondary)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: _proposals.map(_proposalCard).toList(),
    );
  }

  Widget _proposalCard(ActivityProposal p) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name,
                style: const TextStyle(
                    color: AColors.violetDark,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                pill(Icons.category, p.category.label, AColors.violet),
                pill(Icons.timer, '${p.durationMin} min', AColors.textSecondary),
                pill(Icons.signal_cellular_alt, p.level.label, AColors.violet),
              ],
            ),
            if (p.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(p.description,
                  style: const TextStyle(color: Color(0xFF433B5A), height: 1.3)),
            ],
            if (p.objective.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.flag, size: 16, color: AColors.violet),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text('Objectif : ${p.objective}',
                          style: const TextStyle(color: AColors.textSecondary))),
                ],
              ),
            ],
            if (p.justification.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AColors.lilac.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 16, color: AColors.violetDark),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(p.justification,
                          style: const TextStyle(
                              color: AColors.violetDark, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _accept(p),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Ajouter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AColors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => _refuse(p),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AColors.textSecondary,
                    side: const BorderSide(color: AColors.textSecondary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Refuser'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
