import 'package:flutter/material.dart';
import '../../../core/widgets/placeholder_view.dart';

class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(
        title: 'Activités', icon: Icons.fitness_center);
  }
}