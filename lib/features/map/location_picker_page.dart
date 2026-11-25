import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:aletheia_dev/core/config/app_config.dart';
import 'package:aletheia_dev/core/models/place_choice.dart';
import 'package:aletheia_dev/core/services/place_service.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/widgets/app_snack_bar.dart';
import 'package:aletheia_dev/widgets/primary_button.dart';

class _SearchResult {
  const _SearchResult({
    required this.name,
    required this.address,
    required this.point,
  });

  final String name;
  final String address;
  final LatLng point;
}

/// Full-screen map for choosing where a memory happened.
/// Search for a place, tap the map to drop a new pin, tap an existing pin to
/// reuse that place, or use the location button to jump to where you are now.
/// Returns a [PlaceChoice] (or null if cancelled).
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key, this.initial});

  final PlaceChoice? initial;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final _map = MapController();
  final _name = TextEditingController();
  final _searchField = TextEditingController();

  List<PlaceChoice> _existing = [];
  LatLng? _point;
  String? _existingId;
  bool _locating = false;
  bool _mapReady = false;
  LatLng? _pendingCenter;

  List<_SearchResult> _results = [];
  String? _searchMessage;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _point = LatLng(initial.lat, initial.lng);
      _existingId = initial.id;
      _name.text = initial.name;
    }
    _loadPlaces();
  }

  @override
  void dispose() {
    _name.dispose();
    _searchField.dispose();
    _map.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    showAppSnackBar(context, message);
  }

  Future<void> _loadPlaces() async {
    try {
      final places = await PlaceService.fetchAll();
      if (!mounted) return;
      setState(() => _existing = places);

      // With nothing chosen yet, start the view on one of your saved places.
      if (_point == null && places.isNotEmpty) {
        final center = LatLng(places.first.lat, places.first.lng);
        if (_mapReady) {
          _map.move(center, 12);
        } else {
          _pendingCenter = center;
        }
      }
    } catch (e) {
      _snack('Could not load saved places: $e');
    }
  }

  void _selectExisting(PlaceChoice place) {
    setState(() {
      _point = LatLng(place.lat, place.lng);
      _existingId = place.id;
      _name.text = place.name;
    });
  }

  void _dropPin(LatLng point) {
    setState(() {
      if (_existingId != null) _name.clear();
      _point = point;
      _existingId = null;
    });
  }

  /// Searches OpenStreetMap's Nominatim service. The public server's policy
  /// allows about one request per second and no search-as-you-type, so this
  /// only runs when you submit the search.
  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty || _searching) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _results = [];
      _searchMessage = null;
    });
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': q,
        'format': 'jsonv2',
        'limit': '6',
      });
      final response = await http
          .get(uri, headers: {'User-Agent': AppConfig.searchUserAgent})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('server returned ${response.statusCode}');
      }
      final data = jsonDecode(response.body) as List;
      final results = [
        for (final r in data)
          _SearchResult(
            name: (r['display_name'] as String).split(',').first.trim(),
            address: r['display_name'] as String,
            point: LatLng(
              double.parse(r['lat'] as String),
              double.parse(r['lon'] as String),
            ),
          ),
      ];
      if (!mounted) return;
      setState(() {
        _results = results;
        _searchMessage = results.isEmpty ? 'No results found.' : null;
      });
    } catch (e) {
      if (mounted) setState(() => _searchMessage = 'Search failed: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pickResult(_SearchResult result) {
    _dropPin(result.point);
    _name.text = result.name;
    _map.move(result.point, 16);
    setState(() {
      _results = [];
      _searchMessage = null;
    });
  }

  void _clearSearch() {
    _searchField.clear();
    setState(() {
      _results = [];
      _searchMessage = null;
    });
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack('Turn on location services on your phone and try again.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _snack('Location permission is off. You can still search or tap the map.');
        return;
      }
      final position =
          await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 20));
      final here = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      _dropPin(here);
      _map.move(here, 16);
    } catch (e) {
      _snack('Could not get your location: $e');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _done() {
    final point = _point;
    final name = _name.text.trim();
    if (point == null) {
      _snack('Search for a place or tap the map to drop a pin first.');
      return;
    }
    if (name.isEmpty) {
      _snack('Give this place a name.');
      return;
    }
    Navigator.pop(
      context,
      PlaceChoice(
        id: _existingId,
        name: name,
        lat: point.latitude,
        lng: point.longitude,
      ),
    );
  }

  Widget _buildSearchOverlay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          elevation: 3,
          borderRadius: AppRadius.mdAll,
          child: TextField(
            controller: _searchField,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Search for a place',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: _clearSearch,
                    ),
            ),
          ),
        ),
        if (_results.isNotEmpty || _searchMessage != null)
          Card(
            margin: const EdgeInsets.only(top: AppSpacing.xs),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: _results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(_searchMessage!),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        for (final r in _results)
                          ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.place_outlined,
                              color: AppColors.primary,
                            ),
                            title: Text(r.name),
                            subtitle: Text(
                              r.address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _pickResult(r),
                          ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick a location')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _point ?? const LatLng(20, 0),
                    initialZoom: _point == null ? 2 : 15,
                    onTap: (tapPosition, point) => _dropPin(point),
                    onMapReady: () {
                      _mapReady = true;
                      final pending = _pendingCenter;
                      if (pending != null) {
                        _map.move(pending, 12);
                        _pendingCenter = null;
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: AppConfig.tileUrl,
                      userAgentPackageName: AppConfig.mapUserAgent,
                    ),
                    MarkerLayer(
                      markers: [
                        for (final p in _existing)
                          Marker(
                            point: LatLng(p.lat, p.lng),
                            width: 40,
                            height: 40,
                            alignment: Alignment.topCenter,
                            child: GestureDetector(
                              onTap: () => _selectExisting(p),
                              child: Icon(
                                Icons.location_on,
                                size: 36,
                                color: p.id == _existingId
                                    ? AppColors.danger
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        if (_point != null && _existingId == null)
                          Marker(
                            point: _point!,
                            width: 40,
                            height: 40,
                            alignment: Alignment.topCenter,
                            child: const Icon(
                              Icons.location_on,
                              size: 40,
                              color: AppColors.danger,
                            ),
                          ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: AppSpacing.sm,
                  left: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: _buildSearchOverlay(),
                ),
                Positioned(
                  right: AppSpacing.md,
                  bottom: 36,
                  child: FloatingActionButton.small(
                    heroTag: 'locate',
                    tooltip: 'Use my location',
                    onPressed: _locating ? null : _useMyLocation,
                    child: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
              boxShadow: AppShadows.bar,
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _name,
                      readOnly: _existingId != null,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Place name',
                        helperText: _existingId != null
                            ? 'Saved place (tap the map to pick a different spot)'
                            : 'Search, tap the map, or tap a saved pin to reuse it',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(label: 'Use this location', onPressed: _done),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
