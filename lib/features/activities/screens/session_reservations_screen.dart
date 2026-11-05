import 'package:flutter/material.dart';

import '../../../core/widgets/app_loader.dart';
import '../models/activity_session.dart';
import '../models/reservation_status.dart';
import '../models/session_reservation.dart';
import '../services/reservation_service.dart';
import 'activity_ui.dart';

/// Vue responsable : les inscriptions d'une séance (confirmés + file d'attente).
class SessionReservationsScreen extends StatefulWidget {
  final ActivitySession session;
  const SessionReservationsScreen({super.key, required this.session});

  @override
  State<SessionReservationsScreen> createState() =>
      _SessionReservationsScreenState();
}

class _SessionReservationsScreenState extends State<SessionReservationsScreen> {
  late Future<List<SessionReservation>> _future;

  @override
  void initState() {
    super.initState();
    _future = ReservationService.instance.getForSession(widget.session.id!);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return Scaffold(
      backgroundColor: AColors.grayLight,
      appBar: AppBar(
        title: const Text('Inscriptions'),
        backgroundColor: AColors.violetDark,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _header(s),
          Expanded(
            child: FutureBuilder<List<SessionReservation>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: AppLoader());
                }
                if (snap.hasError) {
                  return Center(child: Text('${snap.error}'));
                }
                final all = snap.data ?? [];
                final confirmed =
                    all.where((r) => r.isConfirmed).toList();
                final waiting =
                    all.where((r) => r.isWaitlisted).toList();
                if (all.isEmpty) {
                  return const Center(
                    child: Text('Aucune inscription pour le moment.',
                        style: TextStyle(color: AColors.textSecondary)),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sectionTitle(
                        'Confirmés (${confirmed.length}/${s.capacityMax})'),
                    ...confirmed.map((r) => _row(r, ReservationStatus.confirmed)),
                    if (waiting.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionTitle('Liste d\'attente (${waiting.length})'),
                      ...waiting.asMap().entries.map((e) =>
                          _row(e.value, ReservationStatus.waitlisted,
                              position: e.key + 1)),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(ActivitySession s) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        color: AColors.violetDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.activityName ?? 'Séance',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${s.dateLabel} · ${s.timeRangeLabel}',
                style: const TextStyle(color: Colors.white70)),
            if (s.coachName != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Coach : ${s.coachName}',
                    style: const TextStyle(color: Colors.white70)),
              ),
          ],
        ),
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: AColors.violetDark,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
      );

  Widget _row(SessionReservation r, ReservationStatus status, {int? position}) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AColors.lilac,
          foregroundColor: AColors.violetDark,
          child: position != null
              ? Text('$position',
                  style: const TextStyle(fontWeight: FontWeight.bold))
              : const Icon(Icons.person, size: 20),
        ),
        title: Text(r.memberName ?? 'Adhérent',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(r.memberEmail ?? '',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: reservationStatusChip(status),
      ),
    );
  }
}
