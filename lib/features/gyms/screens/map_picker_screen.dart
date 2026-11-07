import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/geocoding_service.dart';
import '../services/map_config.dart';

/// Choix de l'emplacement d'une salle sur la carte.
/// Renvoie un [GeoPlace] (coordonnées + adresse + ville) avec Navigator.pop,
/// ou null si l'utilisateur revient en arrière.
class MapPickerScreen extends StatefulWidget {
  final LatLng? initial;
  const MapPickerScreen({super.key, this.initial});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const _violetDark = Color(0xFF4C378E);
  static const _pink = Color(0xFFD43DA7);
  static const _grayLight = Color(0xFFEFEDF5);
  static const _violet = Color(0xFFA86BEE);
  static const _orange = Color(0xFFE8920C);

  final _map = MapController();
  final _searchCtrl = TextEditingController();

  LatLng? _point; // point choisi
  GeoPlace? _place; // adresse trouvée pour ce point
  List<GeoPlace> _results = [];
  bool _searching = false;
  bool _resolving = false;
  bool _locating = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _point = widget.initial;
    if (_point != null) _resolve(_point!);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _map.dispose();
    super.dispose();
  }

  void _setMessage(String? m) {
    if (mounted) setState(() => _message = m);
  }

  /// Cherche l'adresse du point. Si le service échoue, on garde quand même
  /// les coordonnées : l'adresse pourra être saisie à la main dans le formulaire.
  Future<void> _resolve(LatLng p) async {
    setState(() {
      _resolving = true;
      _message = null;
    });
    GeoPlace? found;
    String? error;
    try {
      found = await GeocodingService.instance.reverse(p.latitude, p.longitude);
    } on GeocodingException catch (e) {
      error = e.message;
    }
    // Un autre point a été choisi entre-temps : on ignore ce résultat.
    if (!mounted || _point != p) return;
    setState(() {
      _resolving = false;
      _place = found ??
          GeoPlace(
              latitude: p.latitude, longitude: p.longitude, address: '', city: '');
      _message = error;
    });
  }

  void _onTap(TapPosition _, LatLng point) {
    setState(() {
      _point = point;
      _place = null;
      _results = [];
    });
    _resolve(point);
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _message = null;
    });
    try {
      final res = await GeocodingService.instance.search(_searchCtrl.text);
      if (!mounted) return;
      setState(() {
        _results = res;
        _message = res.isEmpty ? 'Aucun résultat pour cette recherche.' : null;
      });
    } on GeocodingException catch (e) {
      _setMessage(e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectResult(GeoPlace r) {
    final p = LatLng(r.latitude, r.longitude);
    setState(() {
      _point = p;
      _place = r;
      _results = [];
      _message = null;
    });
    _map.move(p, 16);
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _message = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setMessage('Activez la localisation de l\'appareil.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _setMessage('Permission de localisation refusée.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      final p = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _point = p;
        _place = null;
        _results = [];
      });
      _map.move(p, 16);
      _resolve(p);
    } catch (_) {
      _setMessage('Position introuvable. Placez le marqueur à la main.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = _point;
    final place = _place;
    final canConfirm = point != null && !_resolving && place != null;

    String info;
    if (point == null) {
      info = 'Touchez la carte pour placer le marqueur.';
    } else if (_resolving) {
      info = 'Recherche de l\'adresse...';
    } else if (place != null && place.label.isNotEmpty) {
      info = place.label;
    } else {
      info = 'Adresse introuvable : vous pourrez la saisir à la main.';
    }

    return Scaffold(
      backgroundColor: _grayLight,
      appBar: AppBar(
        title: const Text('Localisation de la salle'),
        backgroundColor: _violetDark,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: widget.initial ?? MapConfig.defaultCenter,
              initialZoom: widget.initial != null ? 16 : MapConfig.defaultZoom,
              onTap: _onTap,
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.tileUrl,
                userAgentPackageName: MapConfig.userAgentPackage,
              ),
              if (point != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 48,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child:
                          const Icon(Icons.location_on, color: _pink, size: 48),
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

          // Recherche d'adresse
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Material(
                  elevation: 3,
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Rechercher une adresse, une ville...',
                      prefixIcon: const Icon(Icons.search, color: _violet),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.arrow_forward,
                                  color: _violetDark),
                              onPressed: _search,
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (_results.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 240),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = _results[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.place, color: _violet),
                            title: Text(
                              r.label.isEmpty ? 'Lieu sans nom' : r.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: _violetDark),
                            ),
                            onTap: () => _selectResult(r),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bouton "ma position" + carte de confirmation
          Positioned(
            left: 12,
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'locate',
                  backgroundColor: Colors.white,
                  foregroundColor: _violetDark,
                  onPressed: _locating ? null : _locate,
                  child: _locating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: _pink),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              info,
                              style: const TextStyle(
                                color: _violetDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 6),
                        Text(_message!,
                            style:
                                const TextStyle(color: _orange, fontSize: 12)),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: canConfirm
                              ? () => Navigator.pop(context, place)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _pink,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('Confirmer cette localisation'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
