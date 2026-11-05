import 'package:flutter/material.dart';

import '../widgets/nutrition_ui.dart';
import 'food_journal_screen.dart';
import 'nutrition_coach_screen.dart';
import 'nutrition_dashboard_screen.dart';
import 'nutrition_profile_screen.dart';

/// Conteneur du module Nutrition avec la navigation inférieure (4 sections).
/// Chaque onglet est reconstruit à l'affichage, ce qui rafraîchit les données
/// (ex. le dashboard se met à jour après l'ajout d'un repas).
class NutritionShellScreen extends StatefulWidget {
  const NutritionShellScreen({super.key});

  @override
  State<NutritionShellScreen> createState() => _NutritionShellScreenState();
}

class _NutritionShellScreenState extends State<NutritionShellScreen> {
  int _index = 0;

  Widget _screen() {
    switch (_index) {
      case 0:
        return const NutritionDashboardScreen();
      case 1:
        return const FoodJournalScreen();
      case 2:
        return const NutritionCoachScreen();
      default:
        return const NutritionProfileScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NColors.bg,
      body: SafeArea(bottom: false, child: _screen()),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: NColors.lavender,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          backgroundColor: Colors.white,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard, color: NColors.primary),
                label: 'Accueil'),
            NavigationDestination(
                icon: Icon(Icons.restaurant_outlined),
                selectedIcon: Icon(Icons.restaurant, color: NColors.primary),
                label: 'Repas'),
            NavigationDestination(
                icon: Icon(Icons.smart_toy_outlined),
                selectedIcon: Icon(Icons.smart_toy, color: NColors.primary),
                label: 'Coach IA'),
            NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person, color: NColors.primary),
                label: 'Profil'),
          ],
        ),
      ),
    );
  }
}
