import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/session/session_manager.dart';
import '../models/gym_membership.dart';

/// Carte d'adhérent numérique avec QR code.
/// Le QR contient uniquement le jeton aléatoire de l'adhésion : il ne révèle
/// rien et ne peut pas être deviné. Le responsable le vérifie à l'entrée.
class MembershipCardScreen extends StatelessWidget {
  static const _violetDark = Color(0xFF4C378E);
  static const _grayLight = Color(0xFFEFEDF5);
  static const _violet = Color(0xFFA86BEE);
  static const _textSecondary = Color(0xFF7A7390);

  final GymMembership membership;
  const MembershipCardScreen({super.key, required this.membership});

  @override
  Widget build(BuildContext context) {
    final m = membership;
    final token = m.qrToken;
    final valid = m.isActive && token != null && token.isNotEmpty;
    final name = SessionManager.instance.currentUser?.fullName ??
        m.memberName ??
        '';

    return Scaffold(
      backgroundColor: _grayLight,
      appBar: AppBar(
        title: const Text('Carte d\'adhérent'),
        backgroundColor: _violetDark,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_violetDark, _violet],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: _violet.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('MyGym',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    Spacer(),
                    Icon(Icons.fitness_center, color: Colors.white70),
                  ],
                ),
                const SizedBox(height: 22),
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '${m.gymName ?? 'Salle'}'
                  '${(m.gymCity ?? '').isEmpty ? '' : ' · ${m.gymCity}'}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _info('FORMULE', m.formulaLabel),
                    const SizedBox(width: 28),
                    _info(
                      'EXPIRE LE',
                      m.endDate == null
                          ? '—'
                          : GymMembership.formatDate(m.endDate!),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: valid
                        ? QrImageView(
                            data: token!,
                            version: QrVersions.auto,
                            size: 200,
                            backgroundColor: Colors.white,
                          )
                        : const SizedBox(
                            width: 200,
                            height: 200,
                            child: Center(
                              child: Text(
                                'Cette carte n\'est plus valide.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: _textSecondary),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (valid) ...[
            const Text('Code de la carte',
                style: TextStyle(color: _textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      m.codeLabel,
                      style: const TextStyle(
                        color: _violetDark,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copier',
                    icon: const Icon(Icons.copy, color: _violet),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: token!));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: _violetDark,
                          content: Text('Code copié.'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Présentez ce QR code à l\'entrée de la salle. Si le scan ne '
              'fonctionne pas, le responsable peut saisir le code ci-dessus.',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _info(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ],
      );
}
