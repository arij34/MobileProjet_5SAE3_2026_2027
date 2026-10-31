import 'dart:io';
import 'package:flutter/material.dart';

/// Affiche la miniature d'un justificatif (photo) ; un clic l'ouvre en plein écran.
class ProofViewer extends StatelessWidget {
  final String? proofPath;

  const ProofViewer({super.key, required this.proofPath});

  @override
  Widget build(BuildContext context) {
    final path = proofPath;

    // Cas 1 : aucun justificatif enregistré
    if (path == null || path.isEmpty) {
      return _message(Icons.warning_amber_rounded, 'Aucun justificatif');
    }

    final file = File(path);

    // Cas 2 : le chemin existe en base mais le fichier a disparu
    if (!file.existsSync()) {
      return _message(Icons.broken_image_outlined, 'Fichier introuvable');
    }

    // Cas 3 : le fichier existe, on affiche la miniature
    return GestureDetector(
      onTap: () => _openFullScreen(context, file),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          file,
          height: 140,
          width: double.infinity,
          fit: BoxFit.cover,
          // Si le fichier n'est pas une image lisible
          errorBuilder: (_, _, _) =>
              _message(Icons.broken_image_outlined, 'Image illisible'),
        ),
      ),
    );
  }

  Widget _message(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.orange),
        const SizedBox(width: 8),
        Flexible(child: Text(text)),
      ],
    );
  }

  void _openFullScreen(BuildContext context, File file) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Justificatif professionnel'),
          ),
          body: Center(
            // InteractiveViewer permet de zoomer avec deux doigts
            child: InteractiveViewer(child: Image.file(file)),
          ),
        ),
      ),
    );
  }
}