import 'package:flutter/material.dart';

import 'nutrition_ui.dart';

/// Bulle de message du Coach IA (utilisateur à droite, assistant à gauche).
class ChatBubble extends StatelessWidget {
  final bool fromUser;
  final Widget child;
  const ChatBubble({super.key, required this.fromUser, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: fromUser ? NColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromUser ? 16 : 4),
            bottomRight: Radius.circular(fromUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: NColors.primary.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: TextStyle(
              color: fromUser ? Colors.white : NColors.textDark,
              height: 1.35,
              fontSize: 14),
          child: child,
        ),
      ),
    );
  }
}
