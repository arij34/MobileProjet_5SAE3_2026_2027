import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Résultat d'une demande de position : un point, ou un message d'erreur.
class LocationResult {
  final LatLng? point;
  final String? error;
  const LocationResult({this.point, this.error});
}

/// Position GPS de l'adhérent (catalogue avec distance, recommandation).
class UserLocationService {
  UserLocationService._();
  static final UserLocationService instance = UserLocationService._();

  /// Dernière position trouvée pendant cette session.
  LatLng? lastKnown;

  Future<LatLng> _fetch() async {
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 12),
      ),
    );
    lastKnown = LatLng(pos.latitude, pos.longitude);
    return lastKnown!;
  }

  /// Essaie d'obtenir la position SANS afficher de demande de permission :
  /// renvoie null si elle n'est pas déjà accordée.
  Future<LatLng?> tryGetSilently() async {
    if (lastKnown != null) return lastKnown;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.whileInUse &&
          perm != LocationPermission.always) {
        return null;
      }
      return await _fetch();
    } catch (_) {
      return null;
    }
  }

  /// Demande la permission si besoin, puis la position.
  Future<LocationResult> request() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(
            error: 'Activez la localisation de l\'appareil.');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return const LocationResult(
            error: 'Permission de localisation refusée.');
      }
      return LocationResult(point: await _fetch());
    } catch (_) {
      return const LocationResult(
          error: 'Position introuvable. Réessayez ou choisissez une ville.');
    }
  }
}
