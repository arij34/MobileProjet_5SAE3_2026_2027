import 'dart:math';

/// Calculs de distance entre deux points GPS.
class GeoUtils {
  GeoUtils._();

  static double _rad(double deg) => deg * pi / 180;

  /// Distance à vol d'oiseau en kilomètres (formule de Haversine).
  static double distanceKm(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = pow(sin(dLat / 2), 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * pow(sin(dLon / 2), 2);
    return 2 * earthRadiusKm * asin(sqrt(a));
  }

  /// "850 m" sous 1 km, sinon "3.2 km".
  static String format(double km) =>
      km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
}
