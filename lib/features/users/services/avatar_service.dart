/// Construit les adresses des avatars de l'API DiceBear (https://www.dicebear.com).
class AvatarService {
  AvatarService._();

  static const String _baseUrl = 'https://api.dicebear.com/10.x';

  /// Styles proposés à l'utilisateur.
  static const List<String> styles = [
    'adventurer',
    'avataaars',
    'bottts',
    'lorelei',
    'micah',
    'thumbs',
  ];

  /// Adresse de l'image PNG d'un avatar : même style + même seed = même avatar.
  static String urlFor(String style, String seed) =>
      '$_baseUrl/$style/png?seed=${Uri.encodeComponent(seed)}&size=256';
}