import 'package:image_picker/image_picker.dart';

import 'package:aletheia_dev/core/models/place_choice.dart';
import 'package:aletheia_dev/core/services/photo_service.dart';
import 'package:aletheia_dev/core/services/place_service.dart';
import 'package:aletheia_dev/core/services/supabase_client.dart';
import 'package:aletheia_dev/core/state/entries_revision.dart';
import 'package:aletheia_dev/core/utils/date_format.dart';

/// Everything that reads or writes memories (the `entries` table) and their
/// photos. Screens call these instead of talking to Supabase directly.
/// Every change calls [notifyEntriesChanged] so listing screens reload.
abstract final class EntryService {
  /// Loads entries (newest first) with their place, photo count, and a
  /// temporary signed link for each entry's first photo (the bucket is
  /// private).
  static Future<List<Map<String, dynamic>>> fetchAll() async {
    final data = await supabase
        .from('entries')
        .select('*, media(storage_path), places(id, name, lat, lng)')
        .order('happened_at', ascending: false)
        .order('created_at', ascending: false);

    final thumbPaths = <String>[];
    final thumbIndexByEntry = <int, int>{};
    for (var i = 0; i < data.length; i++) {
      final media = (data[i]['media'] as List?) ?? const [];
      if (media.isNotEmpty) {
        thumbIndexByEntry[i] = thumbPaths.length;
        thumbPaths.add(media.first['storage_path'] as String);
      }
    }

    final urls = await PhotoService.signedUrls(thumbPaths);

    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < data.length; i++) {
      final media = (data[i]['media'] as List?) ?? const [];
      final urlIndex = thumbIndexByEntry[i];
      result.add({
        ...data[i],
        'photo_count': media.length,
        'thumb_url': urlIndex == null ? null : urls[urlIndex],
      });
    }
    return result;
  }

  /// Storage paths and signed links for one entry's photos.
  static Future<({List<String> paths, List<String> urls})> loadPhotos(
    String entryId,
  ) async {
    final rows = await supabase
        .from('media')
        .select('storage_path')
        .eq('entry_id', entryId)
        .order('storage_path');
    final paths = [for (final r in rows) r['storage_path'] as String];
    final urls = await PhotoService.signedUrls(paths);
    return (paths: paths, urls: urls);
  }

  /// Creates a memory (and its place, if new) and uploads its photos.
  static Future<String> create({
    required String title,
    String? note,
    required DateTime date,
    PlaceChoice? place,
    List<XFile> photos = const [],
  }) async {
    try {
      // 1. Create the place first if it's a new one.
      final placeId = await PlaceService.resolveId(place);

      // 2. Create the entry and get its id back.
      final inserted = await supabase
          .from('entries')
          .insert({
            'type': 'moment',
            'title': title,
            'note': note,
            'happened_at': dateOnly(date),
            'place_id': placeId,
          })
          .select('id')
          .single();
      final id = inserted['id'] as String;

      // 3. Upload the photos and record them.
      await PhotoService.upload(id, photos);
      return id;
    } finally {
      notifyEntriesChanged();
    }
  }

  /// Updates a memory. The place is only touched when [placeTouched] is true
  /// (passing a null [place] then removes it). Returns the updated row.
  static Future<Map<String, dynamic>> update({
    required String id,
    required String title,
    String? note,
    required DateTime date,
    PlaceChoice? place,
    required bool placeTouched,
    List<XFile> newPhotos = const [],
  }) async {
    try {
      final changes = <String, dynamic>{
        'title': title,
        'note': note,
        'happened_at': dateOnly(date),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (placeTouched) {
        changes['place_id'] = await PlaceService.resolveId(place);
      }
      final updated = await supabase
          .from('entries')
          .update(changes)
          .eq('id', id)
          .select('*, places(id, name, lat, lng)')
          .single();
      await PhotoService.upload(id, newPhotos);
      return updated;
    } finally {
      notifyEntriesChanged();
    }
  }

  static Future<void> addPhotos(String entryId, List<XFile> photos) async {
    try {
      await PhotoService.upload(entryId, photos);
    } finally {
      notifyEntriesChanged();
    }
  }

  /// Deletes the photos from storage first, then the entry (its media rows
  /// are removed with it).
  static Future<void> delete(String id, List<String> photoPaths) async {
    try {
      await PhotoService.removeFromStorage(photoPaths);
      await supabase.from('entries').delete().eq('id', id);
    } finally {
      notifyEntriesChanged();
    }
  }
}
