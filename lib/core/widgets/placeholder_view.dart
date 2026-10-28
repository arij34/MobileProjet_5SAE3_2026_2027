import 'package:flutter/material.dart';

/// Écran provisoire affiché tant qu'un module n'est pas développé.
class PlaceholderView extends StatelessWidget {
  final String title;
  final IconData icon;

  const PlaceholderView({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Module en cours de développement'),
        ],
      ),
    );
  }
}