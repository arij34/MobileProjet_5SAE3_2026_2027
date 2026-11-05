import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/secrets.dart';
import '../models/activity_session.dart';

/// Issue d'un ajout au calendrier.
enum CalendarResult {
  added, // évènement créé
  duplicate, // déjà ajouté (id connu) : rien à refaire
  signInCancelled, // l'utilisateur a refusé la connexion Google
  failed, // erreur réseau / API / OAuth
}

class CalendarAddOutcome {
  final CalendarResult result;
  final String? eventId;
  const CalendarAddOutcome(this.result, {this.eventId});
}

/// Ajoute une séance réservée au Google Agenda de l'adhérent.
///
/// OAuth géré par google_sign_in ; l'appel à l'API Calendar se fait ensuite en
/// HTTP/JSON direct (events.insert). Aucun backend. Les doublons sont évités en
/// stockant l'id de l'évènement créé sur la réservation : si l'id existe déjà,
/// on ne recrée rien.
class CalendarService {
  CalendarService._();
  static final CalendarService instance = CalendarService._();

  static const String _scope =
      'https://www.googleapis.com/auth/calendar.events';
  static const String _eventsUrl =
      'https://www.googleapis.com/calendar/v3/calendars/primary/events';

  GoogleSignIn? _signIn;

  GoogleSignIn get _google => _signIn ??= GoogleSignIn(
        scopes: const [_scope],
        serverClientId:
            googleServerClientId.isEmpty ? null : googleServerClientId,
      );

  /// Ajoute [session] à l'agenda. [existingEventId] = id déjà enregistré pour
  /// cette réservation (anti-doublon). [coachName] enrichit la description.
  Future<CalendarAddOutcome> addSession({
    required ActivitySession session,
    String? existingEventId,
  }) async {
    if (existingEventId != null && existingEventId.isNotEmpty) {
      return CalendarAddOutcome(CalendarResult.duplicate,
          eventId: existingEventId);
    }

    try {
      GoogleSignInAccount? account = await _google.signInSilently();
      account ??= await _google.signIn();
      if (account == null) {
        return const CalendarAddOutcome(CalendarResult.signInCancelled);
      }

      final auth = await account.authentication;
      final token = auth.accessToken;
      if (token == null) {
        return const CalendarAddOutcome(CalendarResult.failed);
      }

      final descriptionParts = <String>[
        if ((session.activityName ?? '').isNotEmpty)
          'Activité : ${session.activityName}',
        if ((session.gymName ?? '').isNotEmpty) 'Salle : ${session.gymName}',
        if ((session.coachName ?? '').isNotEmpty)
          'Coach : ${session.coachName}',
      ];

      final event = <String, dynamic>{
        'summary': session.activityName ?? 'Séance de sport',
        'location': session.gymName,
        'description': descriptionParts.join('\n'),
        'start': {
          'dateTime': session.startAt.toUtc().toIso8601String(),
          'timeZone': 'UTC',
        },
        'end': {
          'dateTime': session.endAt.toUtc().toIso8601String(),
          'timeZone': 'UTC',
        },
      };

      final response = await http
          .post(
            Uri.parse(_eventsUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(event),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return CalendarAddOutcome(CalendarResult.added,
            eventId: data['id'] as String?);
      }
      debugPrint('Google Calendar ${response.statusCode} : ${response.body}');
      return const CalendarAddOutcome(CalendarResult.failed);
    } catch (e) {
      debugPrint('Google Calendar erreur : $e');
      return const CalendarAddOutcome(CalendarResult.failed);
    }
  }
}
