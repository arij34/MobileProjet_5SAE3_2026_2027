import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Un lieu trouvé par le géocodage : coordonnées + adresse lisible.
class GeoPlace {
  final double latitude;
  final double longitude;
  final String address; // rue, numéro, quartier (peut être vide)
  final String city; // ville (peut être vide)

  const GeoPlace({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
  });

  /// Texte affiché dans les listes et sur la carte.
  String get label => [address, city].where((s) => s.isNotEmpty).join(', ');
}

/// Erreur avec un message affichable à l'utilisateur.
class GeocodingException implements Exception {
  final String message;
  GeocodingException(this.message);

  @override
  String toString() => message;
}

/// Recherche d'adresse et géocodage inverse avec Nominatim (OpenStreetMap).
///
/// Règles de Nominatim : 1 requête par seconde au maximum, un User-Agent
/// obligatoire, pas de recherche à chaque frappe (le service impose le délai).
class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  static const String _host = 'nominatim.openstreetmap.org';
  static const String _userAgent = 'MyGymApp/1.0 (projet universitaire MyGym)';
  static const Duration _minDelay = Duration(milliseconds: 1100);

  DateTime? _lastCall;

  /// Attend si la dernière requête date de moins d'une seconde.
  Future<void> _throttle() async {
    final last = _lastCall;
    if (last != null) {
      final wait = _minDelay - DateTime.now().difference(last);
      if (wait > Duration.zero) await Future.delayed(wait);
    }
    _lastCall = DateTime.now();
  }

  Future<dynamic> _get(Uri uri) async {
    await _throttle();
    try {
      final response = await http.get(uri, headers: {
        'User-Agent': _userAgent,
        'Accept-Language': 'fr',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw GeocodingException(
            'Service de localisation indisponible (code ${response.statusCode}).');
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on SocketException {
      throw GeocodingException('Pas de connexion Internet.');
    } on TimeoutException {
      throw GeocodingException('Le service de localisation ne répond pas.');
    } on http.ClientException {
      throw GeocodingException('Pas de connexion Internet.');
    } on FormatException {
      throw GeocodingException('Réponse du service illisible.');
    }
  }

  /// Cherche une adresse ou un lieu. [countryCodes] limite la recherche
  /// (ex. 'tn' pour la Tunisie ; null = monde entier).
  Future<List<GeoPlace>> search(String query, {String? countryCodes = 'tn'}) async {
    final q = query.trim();
    if (q.length < 3) {
      throw GeocodingException('Tapez au moins 3 caractères.');
    }
    final uri = Uri.https(_host, '/search', {
      'q': q,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '5',
      if (countryCodes != null) 'countrycodes': countryCodes,
    });
    final data = await _get(uri);
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((j) => _fromJson(j.cast<String, dynamic>()))
        .toList();
  }

  /// Trouve l'adresse d'un point (null si rien n'est trouvé).
  Future<GeoPlace?> reverse(double latitude, double longitude) async {
    final uri = Uri.https(_host, '/reverse', {
      'lat': '$latitude',
      'lon': '$longitude',
      'format': 'jsonv2',
      'addressdetails': '1',
      'zoom': '18',
    });
    final data = await _get(uri);
    if (data is! Map || data.containsKey('error')) return null;
    final place = _fromJson(data.cast<String, dynamic>());
    // On garde le point exact touché, pas celui du bâtiment trouvé.
    return GeoPlace(
      latitude: latitude,
      longitude: longitude,
      address: place.address,
      city: place.city,
    );
  }

  GeoPlace _fromJson(Map<String, dynamic> j) {
    final addr = (j['address'] as Map?)?.cast<String, dynamic>() ?? {};

    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = addr[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    final city =
        pick(['city', 'town', 'village', 'municipality', 'county', 'state']) ??
            '';
    final street = [pick(['house_number']), pick(['road', 'pedestrian', 'footway'])]
        .whereType<String>()
        .join(' ');
    final area = pick(['neighbourhood', 'suburb', 'quarter']);

    var address =
        [street, area].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    if (address.isEmpty) {
      // Plan B : les deux premiers morceaux du nom complet.
      final name = (j['display_name'] ?? '').toString();
      address = name.split(',').take(2).map((s) => s.trim()).join(', ');
    }

    return GeoPlace(
      latitude: double.parse(j['lat'].toString()),
      longitude: double.parse(j['lon'].toString()),
      address: address,
      city: city,
    );
  }
}
