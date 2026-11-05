import 'package:flutter/material.dart';

/// Identité visuelle du module Nutrition (maquette : violet #8B5CF6).
class NColors {
  NColors._();
  static const primary = Color(0xFF8B5CF6); // violet principal
  static const lavender = Color(0xFFF3EEFF); // lavande claire
  static const bg = Color(0xFFF7F7FB); // fond gris très clair
  static const card = Colors.white;
  static const textDark = Color(0xFF2E2A3F);
  static const textSecondary = Color(0xFF8A86A0);

  static const calories = Color(0xFF22C55E); // vert
  static const protein = Color(0xFF8B5CF6); // violet
  static const carbs = Color(0xFFF59E0B); // orange
  static const fats = Color(0xFF38BDF8); // bleu clair
  static const water = Color(0xFF38BDF8);
  static const danger = Color(0xFFEF4444);
}

void showNSnack(BuildContext context, String message, {Color? color}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color ?? NColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
}

/// Carte blanche arrondie avec ombre légère (style maquette).
class NCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const NCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: NColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: NColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: content,
    );
  }
}

/// Bouton principal violet arrondi.
class NButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Color? color;
  const NButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? NColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                  Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
      ),
    );
  }
}
