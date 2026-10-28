import 'package:flutter/material.dart';
import '../../../core/widgets/placeholder_view.dart';

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(
        title: 'Challenges', icon: Icons.emoji_events);
  }
}