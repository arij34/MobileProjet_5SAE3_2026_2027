import 'package:flutter/material.dart';

import '../../../core/session/permissions.dart';
import 'activity_ui.dart';
import 'available_sessions_screen.dart';
import 'manage_activities_screen.dart';
import 'my_reservations_screen.dart';

/// Point d'entrée du module Activités : aiguille selon le rôle.
/// - Responsable de salle -> gestion des activités et du planning.
/// - Adhérent -> séances disponibles + ses réservations.
/// - Autres rôles (lecture) -> séances disponibles.
class ActivitiesHomeScreen extends StatelessWidget {
  const ActivitiesHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (Permissions.currentCan(Permission.manageActivities)) {
      return const ManageActivitiesScreen();
    }
    if (Permissions.currentCan(Permission.bookSession)) {
      return const _MemberActivitiesScreen();
    }
    return Scaffold(
      backgroundColor: AColors.grayLight,
      appBar: AppBar(
        title: const Text('Activités'),
        backgroundColor: AColors.violetDark,
        foregroundColor: Colors.white,
      ),
      body: const AvailableSessionsScreen(),
    );
  }
}

/// Deux onglets pour l'adhérent : séances disponibles et historique.
class _MemberActivitiesScreen extends StatelessWidget {
  const _MemberActivitiesScreen();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AColors.grayLight,
        appBar: AppBar(
          title: const Text('Activités'),
          backgroundColor: AColors.violetDark,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: AColors.pink,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Séances', icon: Icon(Icons.event_available)),
              Tab(text: 'Mes réservations', icon: Icon(Icons.bookmark)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AvailableSessionsScreen(),
            MyReservationsScreen(),
          ],
        ),
      ),
    );
  }
}
