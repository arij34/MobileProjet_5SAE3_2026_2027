import 'package:flutter/material.dart';
import '../../../core/widgets/placeholder_view.dart';

class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(
        title: 'Nutrition', icon: Icons.restaurant_menu);
  }
}