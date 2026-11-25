import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:aletheia_dev/core/config/app_config.dart';
import 'package:aletheia_dev/core/services/place_service.dart';
import 'package:aletheia_dev/core/state/entries_revision.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/core/utils/date_format.dart';
import 'package:aletheia_dev/features/entry/entry_detail_page.dart';
import 'package:aletheia_dev/widgets/app_snack_bar.dart';
import 'package:aletheia_dev/widgets/empty_state.dart';

/// Map tab: every place that has at least one memory. Tap a pin to see the
/// memories there. Places that are the same spot are shown as one pin.
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  List<Map<String, dynamic>>? _places;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    entriesRevision.addListener(_onEntriesChanged);
    _load();
  }

  @override
  void dispose() {
    entriesRevision.removeListener(_onEntriesChanged);
    super.dispose();
  }

  void _onEntriesChanged() {
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await PlaceService.fetchWithEntries();
      if (!mounted) return;
      setState(() {
        _places = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final hadData = _places != null;
      setState(() {
        _error = e;
        _loading = false;
      });
      if (hadData) showAppSnackBar(context, 'Could not refresh the map: $e');
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _load();
  }

  LatLng _pointOf(Map<String, dynamic> place) => LatLng(
        (place['lat'] as num).toDouble(),
        (place['lng'] as num).toDouble(),
      );

  void _showPlace(Map<String, dynamic> place) {
    final entries = List<Map<String, dynamic>>.from(place['entries'] as List);
    entries.sort(
      (a, b) =>
          (b['happened_at'] as String).compareTo(a['happened_at'] as String),
    );
    final count = entries.length;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final textTheme = Theme.of(sheetContext).textTheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        place['name'] as String,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.sm,
                ),
                child: Text(
                  '$count ${count == 1 ? 'memory' : 'memories'} here',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final e in entries)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                        ),
                        title: Text(
                          e['title'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(displayDateOf(e['happened_at'])),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.textHint,
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _openEntry(e, place);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openEntry(Map<String, dynamic> entry, Map<String, dynamic> place) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EntryDetailPage(
          entry: {
            ...entry,
            'places': {
              'id': place['id'],
              'name': place['name'],
              'lat': place['lat'],
              'lng': place['lng'],
            },
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _places == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _places == null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load the map',
        message: '$_error',
        actionLabel: 'Try again',
        onAction: _retry,
      );
    }

    final places = _places ?? const <Map<String, dynamic>>[];
    final points = [for (final p in places) _pointOf(p)];

    final MapOptions options;
    if (points.isEmpty) {
      options = const MapOptions(
        initialCenter: LatLng(20, 0),
        initialZoom: 2,
      );
    } else if (points.length == 1) {
      options = MapOptions(initialCenter: points.first, initialZoom: 14);
    } else {
      options = MapOptions(
        initialCameraFit: CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(56),
          maxZoom: 15,
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          options: options,
          children: [
            TileLayer(
              urlTemplate: AppConfig.tileUrl,
              userAgentPackageName: AppConfig.mapUserAgent,
            ),
            MarkerLayer(
              markers: [
                for (final p in places)
                  Marker(
                    point: _pointOf(p),
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => _showPlace(p),
                      child: const Icon(
                        Icons.location_on,
                        size: 44,
                        color: AppColors.primary,
                      ),
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
        if (places.isEmpty)
          const Align(
            alignment: Alignment.topCenter,
            child: Card(
              margin: EdgeInsets.all(AppSpacing.lg),
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'No places yet. Add a location to a memory and it will show up here.',
                ),
              ),
            ),
          ),
      ],
    );
  }
}
