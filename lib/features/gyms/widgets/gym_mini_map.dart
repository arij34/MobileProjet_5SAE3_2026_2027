import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/map_config.dart';

/// Petite carte non interactive qui montre l'emplacement d'une salle.
/// Si [onTap] est fourni, un appui sur la carte appelle cette fonction.
class GymMiniMap extends StatelessWidget {
  static const _pink = Color(0xFFD43DA7);

  final LatLng point;
  final double height;
  final VoidCallback? onTap;

  const GymMiniMap({
    super.key,
    required this.point,
    this.height = 160,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              key: ValueKey(point), // recentre la carte si le point change
              options: MapOptions(
                initialCenter: point,
                initialZoom: 15,
                interactionOptions:
                    const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(
                  urlTemplate: MapConfig.tileUrl,
                  userAgentPackageName: MapConfig.userAgentPackage,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child:
                          const Icon(Icons.location_on, color: _pink, size: 44),
                    ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            if (onTap != null)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: onTap),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
