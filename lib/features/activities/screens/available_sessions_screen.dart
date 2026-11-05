import 'package:flutter/material.dart';

import '../../../core/session/session_manager.dart';
import '../../../core/widgets/app_loader.dart';
import '../../users/services/user_service.dart' show AuthException;
import '../models/activity_session.dart';
import '../models/reservation_status.dart';
import '../services/email_service.dart';
import '../services/reservation_service.dart';
import '../services/session_service.dart';
import 'activity_ui.dart';

/// Vue adhérent : les séances à venir, avec réservation et liste d'attente.
class AvailableSessionsScreen extends StatefulWidget {
  const AvailableSessionsScreen({super.key});

  @override
  State<AvailableSessionsScreen> createState() =>
      _AvailableSessionsScreenState();
}

class _AvailableSessionsScreenState extends State<AvailableSessionsScreen> {
  final _search = TextEditingController();
  List<ActivitySession> _sessions = [];
  Map<int, ReservationStatus> _myStatus = {};
  bool _loading = true;
  int? _bookingId; // séance en cours de réservation (pour le spinner)

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sessions = await SessionService.instance
          .getAvailableForMembers(search: _search.text);
      final status = await ReservationService.instance.getMyStatusBySession();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _myStatus = status;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _book(ActivitySession s) async {
    setState(() => _bookingId = s.id);
    try {
      final outcome = await ReservationService.instance.book(s.id!);
      if (!mounted) return;
      if (outcome.waitlisted) {
        showASnack(context,
            'Séance complète : vous êtes en liste d\'attente.',
            color: AColors.orange);
      } else {
        showASnack(context, 'Réservation confirmée !', color: AColors.green);
        _sendConfirmationEmail(outcome.session);
      }
      await _load();
    } on AuthException catch (e) {
      if (mounted) showASnack(context, e.message, color: AColors.red);
    } catch (e) {
      if (mounted) showASnack(context, 'Erreur : $e', color: AColors.red);
    } finally {
      if (mounted) setState(() => _bookingId = null);
    }
  }

  /// Email de confirmation : non bloquant, l'état est affiché mais n'empêche rien.
  Future<void> _sendConfirmationEmail(ActivitySession session) async {
    final user = SessionManager.instance.currentUser;
    if (user == null || !EmailService.instance.isConfigured) return;
    showASnack(context, 'Envoi de l\'email de confirmation...');
    final state = await EmailService.instance.send(
      kind: EmailKind.reservation,
      toEmail: user.email,
      toName: user.fullName,
      session: session,
    );
    if (!mounted) return;
    showASnack(
      context,
      state == EmailSendState.sent
          ? 'Email de confirmation envoyé.'
          : 'Email non envoyé (réservation bien enregistrée).',
      color: state == EmailSendState.sent ? AColors.green : AColors.orange,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _searchBar(),
        Expanded(
          child: _loading
              ? const Center(child: AppLoader())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _sessions.isEmpty
                      ? ListView(children: const [
                          Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: Center(
                              child: Text('Aucune séance disponible.',
                                  style: TextStyle(
                                      color: AColors.textSecondary)),
                            ),
                          )
                        ])
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: _sessions.map(_card).toList(),
                        ),
                ),
        ),
      ],
    );
  }

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _load(),
          decoration: InputDecoration(
            hintText: 'Rechercher une activité, une salle...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _search.clear();
                      _load();
                    },
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );

  Widget _card(ActivitySession s) {
    final status = _myStatus[s.id];
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.activityName ?? 'Séance',
                style: const TextStyle(
                    color: AColors.violetDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 2),
            Text('${s.gymName ?? ''} · ${s.dateLabel} · ${s.timeRangeLabel}',
                style: const TextStyle(color: AColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (s.activityCategory != null)
                  pill(Icons.category, s.activityCategory!.label,
                      AColors.violet),
                if (s.coachName != null)
                  pill(Icons.sports, s.coachName!, AColors.violet),
                placesChip(s),
              ],
            ),
            const SizedBox(height: 12),
            _action(s, status),
          ],
        ),
      ),
    );
  }

  Widget _action(ActivitySession s, ReservationStatus? status) {
    if (status == ReservationStatus.confirmed) {
      return pill(Icons.check_circle, 'Vous êtes inscrit', AColors.green);
    }
    if (status == ReservationStatus.waitlisted) {
      return pill(Icons.hourglass_bottom, 'En liste d\'attente',
          AColors.orange);
    }
    final loading = _bookingId == s.id;
    final full = s.isFull;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: loading ? null : () => _book(s),
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white),
              )
            : Icon(full ? Icons.hourglass_empty : Icons.event_available,
                size: 18),
        label: Text(full ? 'Rejoindre la liste d\'attente' : 'Réserver'),
        style: ElevatedButton.styleFrom(
          backgroundColor: full ? AColors.orange : AColors.pink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
