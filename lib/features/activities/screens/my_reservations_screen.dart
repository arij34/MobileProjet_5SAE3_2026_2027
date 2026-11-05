import 'package:flutter/material.dart';

import '../../../core/session/session_manager.dart';
import '../../../core/widgets/app_loader.dart';
import '../../users/services/user_service.dart' show AuthException;
import '../models/activity_session.dart';
import '../models/session_reservation.dart';
import '../services/calendar_service.dart';
import '../services/email_service.dart';
import '../services/reservation_service.dart';
import 'activity_ui.dart';

/// Vue adhérent : l'historique de ses réservations (annulation + Google Agenda).
class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  List<SessionReservation> _items = [];
  bool _loading = true;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await ReservationService.instance.getMine();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(SessionReservation r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la réservation'),
        content: Text('Annuler votre place pour '
            '« ${r.session?.activityName ?? 'cette séance'} » ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AColors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busyId = r.id);
    try {
      final outcome = await ReservationService.instance.cancel(r.id!);
      if (!mounted) return;
      showASnack(context, 'Réservation annulée.', color: AColors.green);
      // Emails non bloquants : annulation (à soi) + promotion (au suivant).
      _sendCancellationEmail(outcome.session);
      if (outcome.promoted != null) {
        _notifyPromoted(outcome.promoted!, outcome.session);
      }
      await _load();
    } on AuthException catch (e) {
      if (mounted) showASnack(context, e.message, color: AColors.red);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _sendCancellationEmail(ActivitySession session) async {
    final user = SessionManager.instance.currentUser;
    if (user == null || !EmailService.instance.isConfigured) return;
    await EmailService.instance.send(
      kind: EmailKind.cancellation,
      toEmail: user.email,
      toName: user.fullName,
      session: session,
    );
  }

  Future<void> _notifyPromoted(
      SessionReservation promoted, ActivitySession session) async {
    if (!EmailService.instance.isConfigured) return;
    final email = promoted.memberEmail;
    if (email == null || email.isEmpty) return;
    await EmailService.instance.send(
      kind: EmailKind.waitlist,
      toEmail: email,
      toName: promoted.memberName ?? 'Adhérent',
      session: session,
    );
  }

  Future<void> _addToCalendar(SessionReservation r) async {
    final session = r.session;
    if (session == null) return;
    setState(() => _busyId = r.id);
    try {
      final outcome = await CalendarService.instance.addSession(
        session: session,
        existingEventId: r.googleEventId,
      );
      if (!mounted) return;
      switch (outcome.result) {
        case CalendarResult.added:
          if (outcome.eventId != null) {
            await ReservationService.instance
                .setGoogleEventId(r.id!, outcome.eventId!);
          }
          if (!mounted) return;
          showASnack(context, 'Ajouté à votre Google Agenda.',
              color: AColors.green);
          await _load();
          break;
        case CalendarResult.duplicate:
          showASnack(context, 'Déjà présent dans votre agenda.',
              color: AColors.orange);
          break;
        case CalendarResult.signInCancelled:
          showASnack(context, 'Connexion Google annulée.',
              color: AColors.orange);
          break;
        case CalendarResult.failed:
          showASnack(context, 'Impossible d\'ajouter à l\'agenda.',
              color: AColors.red);
          break;
      }
    } finally {
      if (mounted && _busyId == r.id) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: AppLoader());
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [
          Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
              child: Text('Aucune réservation pour le moment.',
                  style: TextStyle(color: AColors.textSecondary)),
            ),
          )
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: _items.map(_card).toList(),
      ),
    );
  }

  Widget _card(SessionReservation r) {
    final s = r.session;
    final upcoming = s != null && s.isUpcoming;
    final canCancel = r.isActive && upcoming;
    final canAddCalendar = r.isConfirmed && upcoming;
    final busy = _busyId == r.id;

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
            Row(
              children: [
                Expanded(
                  child: Text(s?.activityName ?? 'Séance',
                      style: const TextStyle(
                          color: AColors.violetDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
                reservationStatusChip(r.status),
              ],
            ),
            const SizedBox(height: 4),
            if (s != null)
              Text('${s.gymName ?? ''} · ${s.dateLabel} · ${s.timeRangeLabel}',
                  style: const TextStyle(color: AColors.textSecondary)),
            if (s != null && s.coachName != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Coach : ${s.coachName}',
                    style: const TextStyle(
                        color: AColors.textSecondary, fontSize: 12)),
              ),
            if (canCancel || canAddCalendar) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (canAddCalendar)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : () => _addToCalendar(r),
                        icon: const Icon(Icons.event, size: 18),
                        label: const Text('Agenda'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AColors.violetDark,
                          side: const BorderSide(color: AColors.violet),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  if (canAddCalendar && canCancel) const SizedBox(width: 10),
                  if (canCancel)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: busy ? null : () => _cancel(r),
                        icon: busy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2, color: Colors.white),
                              )
                            : const Icon(Icons.close, size: 18),
                        label: const Text('Annuler'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AColors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
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
