import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Gère la photo du justificatif (diplôme, carte professionnelle).
class ProofService {
  ProofService._();
  static final ProofService instance = ProofService._();

  final ImagePicker _picker = ImagePicker();

  /// Ouvre la caméra ou la galerie, enregistre l'image dans le dossier
  /// privé de l'application et renvoie son chemin (null si annulé).
  Future<String?> pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1600, // limite la taille du fichier
      imageQuality: 85,
    );
    if (file == null) return null;

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'proofs'));
    if (!await dir.exists()) await dir.create(recursive: true);

    final ext = p.extension(file.path).isEmpty ? '.jpg' : p.extension(file.path);
    final dest = p.join(
      dir.path,
      'proof_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(file.path).copy(dest);
    return dest;
  }

  /// Supprime un fichier justificatif (ex. image remplacée avant l'envoi).
  Future<void> delete(String? path) async {
    if (path == null) return;
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}