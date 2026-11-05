import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/secrets.dart';
import '../models/activity_session.dart';

/// État d'un envoi d'email (pour l'affichage : chargement / envoyé / échec).
enum EmailSendState { idle, loading, sent, failed }

/// Type d'email transactionnel.
enum EmailKind { reservation, cancellation, waitlist }

/// Envoi d'emails aux adhérents via EmailJS (API REST, HTTP/JSON, sans backend).
///
/// Principe : un échec d'envoi ne doit JAMAIS bloquer une réservation. Les
/// méthodes publiques ne lèvent pas d'exception ; elles renvoient un
/// [EmailSendState] (sent / failed) que l'interface peut afficher.
class EmailService {
  EmailService._();
  static final EmailService instance = EmailService._();

  static const String _endpoint =
      'https://api.emailjs.com/api/v1.0/email/send';

  /// La fonctionnalité est active seulement si le service et la clé publique
  /// sont renseignés dans secrets.dart.
  bool get isConfigured =>
      emailJsServiceId.isNotEmpty && emailJsPublicKey.isNotEmpty;

  String _templateFor(EmailKind kind) {
    switch (kind) {
      case EmailKind.reservation:
        return emailJsTemplateReservation;
      case EmailKind.cancellation:
        return emailJsTemplateCancellation;
      case EmailKind.waitlist:
        return emailJsTemplateWaitlist;
    }
  }

  String _defaultMessage(EmailKind kind, ActivitySession s) {
    switch (kind) {
      case EmailKind.reservation:
        return 'Votre réservation pour « ${s.activityName} » est confirmée.';
      case EmailKind.cancellation:
        return 'Votre réservation pour « ${s.activityName} » a bien été annulée.';
      case EmailKind.waitlist:
        return 'Une place s\'est libérée : votre réservation pour '
            '« ${s.activityName} » est maintenant confirmée !';
    }
  }

  /// Envoie l'email correspondant à [kind]. Ne lève jamais : renvoie l'état.
  Future<EmailSendState> send({
    required EmailKind kind,
    required String toEmail,
    required String toName,
    required ActivitySession session,
  }) async {
    if (!isConfigured) {
      debugPrint('EmailJS non configuré : email ignoré (réservation inchangée).');
      return EmailSendState.failed;
    }
    final templateId = _templateFor(kind);
    if (templateId.isEmpty || toEmail.trim().isEmpty) {
      return EmailSendState.failed;
    }

    // Variables mises à disposition du modèle EmailJS. Le modèle doit référencer
    // {{to_email}} (destinataire) et peut utiliser les autres : {{to_name}},
    // {{activity_name}}, {{gym_name}}, {{date}}, {{time}}, {{coach}}, {{message}}.
    final params = <String, String>{
      'to_email': toEmail.trim(),
      'to_name': toName,
      'activity_name': session.activityName ?? '',
      'gym_name': session.gymName ?? '',
      'date': session.dateLabel,
      'time': session.timeRangeLabel,
      'coach': session.coachName ?? 'Non assigné',
      'message': _defaultMessage(kind, session),
    };

    final body = <String, dynamic>{
      'service_id': emailJsServiceId,
      'template_id': templateId,
      'user_id': emailJsPublicKey,
      if (emailJsPrivateKey.isNotEmpty) 'accessToken': emailJsPrivateKey,
      'template_params': params,
    };

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) return EmailSendState.sent;
      debugPrint('EmailJS ${response.statusCode} : ${response.body}');
      return EmailSendState.failed;
    } catch (e) {
      // Réseau coupé, délai dépassé, etc. : on n'interrompt jamais le flux.
      debugPrint('EmailJS erreur : $e');
      return EmailSendState.failed;
    }
  }
}
