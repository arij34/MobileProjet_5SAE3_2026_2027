import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Avatar rond : photo (depuis une adresse web) ou, à défaut, la première lettre.
class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String initial;
  final double radius;

  const UserAvatar({
    super.key,
    required this.photoUrl,
    required this.initial,
    this.radius = 24,
  });

  Widget _letter() => Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.9,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    final hasPhoto = url != null && url.isNotEmpty;
    final size = radius * 2;

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.purpleLight,
      child: hasPhoto
          ? ClipOval(
              child: Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                // Pas d'internet ou erreur : on affiche la lettre.
                errorBuilder: (_, _, _) => _letter(),
                // Pendant le chargement : petit cercle qui tourne.
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return SizedBox(
                    width: size,
                    height: size,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          : _letter(),
    );
  }
}