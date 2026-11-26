import 'package:aletheia_dev/core/models/place_choice.dart';
import 'package:aletheia_dev/core/services/supabase_client.dart';
import 'package:aletheia_dev/core/utils/geo.dart';

/// Reads and writes the `places` table.
abstract final class PlaceService {
  /// Every saved place, A to Z.
  static Future<List<PlaceChoice>> fetchAll() async {
    final rows =
        await supabase.from('places').select('id, name, lat, lng').order('name');
    return [for (final r in rows) PlaceChoice.fromMap(r)];
  }

  /// Places that have at least one memory, with their memories attached.
  /// Places that are the same spot (same name, nearby) are combined so their
  /// memories share one pin.
  static Future<List<Map<String, dynamic>>> fetchWithEntries() async {
    final data = await supabase
        .from('places')
        .select('id, name, lat, lng, entries(id, title, note, happened_at, deleted_at)')
        .order('name');

    final merged = <Map<String, dynamic>>[];
    for (final p in data) {
      final rawEntries = (p['entries'] as List?) ?? const [];
      final entries = [
        for (final e in rawEntries)
          if (e is Map && e['deleted_at'] == null) e,
      ];
      if (entries.isEmpty) continue;

      final choice = PlaceChoice.fromMap(p);
      final index =
          merged.indexWhere((m) => isSameSpot(PlaceChoice.fromMap(m), choice));
      if (index == -1) {
        merged.add({...p, 'entries': List<dynamic>.from(entries)});
      } else {
        (merged[index]['entries'] as List).addAll(entries);
      }
    }
    return merged;
  }

  /// Returns the id of the place's database row. A new place reuses a saved
  /// one when it is the same spot, and is only created if nothing matches.
  /// Returns null when there is no place.
  static Future<String?> resolveId(PlaceChoice? place) async {
    if (place == null) return null;
    if (place.id != null) return place.id;

    final rows = await supabase.from('places').select('id, name, lat, lng');
    for (final row in rows) {
      final existing = PlaceChoice.fromMap(row);
      if (isSameSpot(existing, place)) return existing.id;
    }

    final inserted = await supabase
        .from('places')
        .insert({'name': place.name, 'lat': place.lat, 'lng': place.lng})
        .select('id')
        .single();
    return inserted['id'] as String;
  }
}
