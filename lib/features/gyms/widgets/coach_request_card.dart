import 'package:flutter/material.dart';

import '../models/coach_enums.dart';
import '../models/gym_coach_request.dart';

const _violetDark = Color(0xFF4C378E);
const _pink = Color(0xFFD43DA7);
const _lilac = Color(0xFFE8D8FC);
const _textSecondary = Color(0xFF7A7390);

Color coachRequestColor(CoachRequestStatus s) {
  switch (s) {
    case CoachRequestStatus.accepted:
      return const Color(0xFF2E9E6B);
    case CoachRequestStatus.pending:
      return const Color(0xFFE8920C);
    case CoachRequestStatus.rejected:
      return const Color(0xFFD64545);
    case CoachRequestStatus.cancelled:
      return _textSecondary;
  }
}

/// Demande un message facultatif. Renvoie null si l'utilisateur annule,
/// sinon le texte saisi (peut être vide).
Future<String?> askRequestMessage(BuildContext context, String title) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        maxLines: 3,
        maxLength: 200,
        decoration: const InputDecoration(
            hintText: 'Message (facultatif)'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: const Text('Envoyer',
              style: TextStyle(color: _pink, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

/// Carte d'une demande, vue par la salle ([asGym] = true) ou par le coach.
/// Accepter / Refuser n'apparaissent que pour la partie qui doit répondre ;
/// l'initiateur ne peut qu'annuler.
class CoachRequestCard extends StatelessWidget {
  final GymCoachRequest request;
  final bool asGym;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;

  const CoachRequestCard({
    super.key,
    required this.request,
    required this.asGym,
    this.onAccept,
    this.onReject,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final r = request;
    final fromGym = r.initiatedBy == CoachRequestInitiator.gym;
    final iAmInitiator = asGym ? fromGym : !fromGym;
    final color = coachRequestColor(r.status);

    final title = asGym ? (r.coachName ?? 'Coach') : (r.gymName ?? 'Salle');
    final kind = asGym
        ? (fromGym ? 'Invitation envoyée' : 'Candidature reçue')
        : (fromGym ? 'Invitation reçue' : 'Candidature envoyée');

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
                CircleAvatar(
                  backgroundColor: _lilac,
                  child: Icon(asGym ? Icons.person : Icons.fitness_center,
                      color: _violetDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: _violetDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text(
                        asGym
                            ? kind
                            : '$kind · ${r.gymCity ?? ''}',
                        style: const TextStyle(color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(r.status.label,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
              ],
            ),
            if (r.message.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('« ${r.message} »',
                  style: const TextStyle(
                      color: _violetDark, fontStyle: FontStyle.italic)),
            ],
            if (r.isPending) ...[
              const SizedBox(height: 12),
              if (iAmInitiator)
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD64545),
                      side: const BorderSide(color: Color(0xFFD64545)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Annuler la demande'),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReject,
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
                        onPressed: onAccept,
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
