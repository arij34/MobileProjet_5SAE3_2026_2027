import 'package:latlong2/latlong.dart';

/// Réglages communs de la carte (OpenStreetMap, sans clé API).
class MapConfig {
  MapConfig._();

  /// Fond de carte OpenStreetMap (usage léger : projet, démonstration).
  static const String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Doit correspondre à l'applicationId de android/app/build.gradle.
  /// OpenStreetMap demande d'identifier l'application qui télécharge ses tuiles.
  static const String userAgentPackage = 'com.example.mygym';

  /// Centre par défaut quand aucune position n'est choisie (Monastir).
  static const LatLng defaultCenter = LatLng(35.7643, 10.8113);
  static const double defaultZoom = 13;
}
