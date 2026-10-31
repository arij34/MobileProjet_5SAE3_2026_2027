import 'package:flutter/material.dart';
import '../utils/password_strength.dart';

class PasswordStrengthBar extends StatelessWidget {
  final String password;

  const PasswordStrengthBar({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final s = PasswordStrength.evaluate(password);
    if (password.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: s.progress),
                    duration: const Duration(milliseconds: 300),
                    builder: (_, value, __) => LinearProgressIndicator(
                      value: value,
                      minHeight: 7,
                      backgroundColor: const Color(0xFFE8D8FC),
                      valueColor: AlwaysStoppedAnimation(s.level.color),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                s.level.label,
                style: TextStyle(
                  color: s.level.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (s.missing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Ajoutez : ${s.missing.join(', ')}',
              style: const TextStyle(color: Color(0xFF7A7390), fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}