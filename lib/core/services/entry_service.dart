import 'package:image_picker/image_picker.dart';

import 'package:aletheia_dev/core/models/entry_photo.dart';
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
  static const int defaultPageSize = 20;

  /// Loads a page of active (non-deleted) entries, newest first, with optional
  /// text search ([query]), [startDate]/[endDate] range, and [placeId] filter.
  static Future<List<Map<String, dynamic>>> fetchPage({
    int page = 0,
    int pageSize = defaultPageSize,
    String? query,
    DateTime? startDate,
    DateTime? endDate,
    String? placeId,
  }) async {
    var filter = supabase
        .from('entries')
        .select(
          '*, media!media_entry_id_fkey(id, storage_path, sort_order, is_cover), places(id, name, lat, lng)',
        )
        .isFilter('deleted_at', null);

    final trimmed = query?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      final safe = trimmed.replaceAll(',', ' ');
      filter = filter.or('title.ilike.%$safe%,note.ilike.%$safe%');
    }
    if (placeId != null && placeId.isNotEmpty) {
      filter = filter.eq('place_id', placeId);
    }
    if (startDate != null) {
      final start = DateTime(startDate.year, startDate.month, startDate.day);
      filter = filter.gte('happened_at', isoTimestamp(start));
    }
    if (endDate != null) {
      final endExclusive =
          DateTime(endDate.year, endDate.month, endDate.day + 1);
      filter = filter.lt('happened_at', isoTimestamp(endExclusive));
    }

    final from = page * pageSize;
    final to = from + pageSize - 1;
    final data = await filter
        .order('happened_at', ascending: false)
        .order('created_at', ascending: false)
        .range(from, to);

    return _attachThumbnails(List<Map<String, dynamic>>.from(data));
  }

  /// Loads soft-deleted entries, most recently deleted first.
  static Future<List<Map<String, dynamic>>> fetchDeleted() async {
    final data = await supabase
        .from('entries')
        .select(
          '*, media!media_entry_id_fkey(id, storage_path, sort_order, is_cover), places(id, name, lat, lng)',
        )
        .not('deleted_at', 'is', null)
        .order('deleted_at', ascending: false);

    return _attachThumbnails(List<Map<String, dynamic>>.from(data));
  }

  static Future<List<Map<String, dynamic>>> _attachThumbnails(
    List<Map<String, dynamic>> rows,
  ) async {
    final thumbPaths = <String>[];
    final thumbIndexByEntry = <int, int>{};

    for (var i = 0; i < rows.length; i++) {
      final media = List<Map<String, dynamic>>.from(
        (rows[i]['media'] as List?) ?? const [],
      );
      if (media.isEmpty) continue;

      final coverPath = _pickCoverPath(rows[i]['cover_media_id'] as String?, media);
      if (coverPath != null) {
        thumbIndexByEntry[i] = thumbPaths.length;
        thumbPaths.add(coverPath);
      }
    }

    final urls = await PhotoService.signedUrls(thumbPaths, thumbnail: true);

    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < rows.length; i++) {
      final media = (rows[i]['media'] as List?) ?? const [];
      final urlIndex = thumbIndexByEntry[i];
      result.add({
        ...rows[i],
        'photo_count': media.length,
        'thumb_path': urlIndex == null ? null : thumbPaths[urlIndex],
        'thumb_url': urlIndex == null ? null : urls[urlIndex],
      });
    }
    return result;
  }

  static String? _pickCoverPath(
    String? coverMediaId,
    List<Map<String, dynamic>> media,
  ) {
    if (media.isEmpty) return null;
    if (coverMediaId != null) {
      for (final m in media) {
        if (m['id'] == coverMediaId) return m['storage_path'] as String?;
      }
    }
    for (final m in media) {
      if (m['is_cover'] == true) return m['storage_path'] as String?;
    }
    media.sort((a, b) {
      final orderCmp =
          ((a['sort_order'] as int?) ?? 0).compareTo((b['sort_order'] as int?) ?? 0);
      if (orderCmp != 0) return orderCmp;
      return (a['storage_path'] as String).compareTo(b['storage_path'] as String);
    });
    return media.first['storage_path'] as String?;
  }

  /// Ordered [EntryPhoto]s with signed links for one entry.
  static Future<List<EntryPhoto>> loadPhotos(String entryId) async {
    final entryRow = await supabase
        .from('entries')
        .select('cover_media_id')
        .eq('id', entryId)
        .maybeSingle();
    final coverMediaId = entryRow?['cover_media_id'] as String?;

    final rows = await supabase
        .from('media')
        .select('id, storage_path, sort_order, is_cover')
        .eq('entry_id', entryId)
        .order('sort_order', ascending: true)
        .order('storage_path', ascending: true);

    final paths = [for (final r in rows) r['storage_path'] as String];
    final urls = await PhotoService.signedUrls(paths);

    return [
      for (var i = 0; i < rows.length; i++)
        EntryPhoto(
          id: rows[i]['id'] as String,
          storagePath: paths[i],
          url: urls[i],
          sortOrder: (rows[i]['sort_order'] as int?) ?? i,
          isCover: coverMediaId != null
              ? rows[i]['id'] == coverMediaId
              : (rows[i]['is_cover'] as bool?) ?? (i == 0),
        ),
    ];
  }

  /// Creates a memory (and its place, if new) and uploads its photos.
  static Future<({String id, UploadBatchResult uploadResult})> create({
    required String title,
    String? note,
    required DateTime date,
    PlaceChoice? place,
    List<XFile> photos = const [],
    void Function(int completed, int total)? onUploadProgress,
  }) async {
    try {
      final placeId = await PlaceService.resolveId(place);

      final inserted = await supabase
          .from('entries')
          .insert({
            'type': 'moment',
            'title': title,
            'note': note,
            'happened_at': isoTimestamp(date),
            'place_id': placeId,
          })
          .select('id')
          .single();
      final id = inserted['id'] as String;

      final uploadResult = await PhotoService.uploadWithProgress(
        id,
        photos,
        onProgress: onUploadProgress,
      );
      return (id: id, uploadResult: uploadResult);
    } finally {
      notifyEntriesChanged();
    }
  }

  /// Updates a memory. The place is only touched when [placeTouched] is true
  /// (passing a null [place] then removes it).
  static Future<({Map<String, dynamic> entry, UploadBatchResult uploadResult})>
      update({
    required String id,
    required String title,
    String? note,
    required DateTime date,
    PlaceChoice? place,
    required bool placeTouched,
    List<XFile> newPhotos = const [],
    int startSortOrder = 0,
    void Function(int completed, int total)? onUploadProgress,
  }) async {
    try {
      final changes = <String, dynamic>{
        'title': title,
        'note': note,
        'happened_at': isoTimestamp(date),
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

      final uploadResult = await PhotoService.uploadWithProgress(
        id,
        newPhotos,
        startSortOrder: startSortOrder,
        onProgress: onUploadProgress,
      );
      return (entry: updated, uploadResult: uploadResult);
    } finally {
      notifyEntriesChanged();
    }
  }

  static Future<UploadBatchResult> addPhotos(
    String entryId,
    List<XFile> photos, {
    int startSortOrder = 0,
    void Function(int completed, int total)? onUploadProgress,
  }) async {
    try {
      return await PhotoService.uploadWithProgress(
        entryId,
        photos,
        startSortOrder: startSortOrder,
        onProgress: onUploadProgress,
      );
    } finally {
      notifyEntriesChanged();
    }
  }

  /// Deletes a single photo from storage and the `media` table.
  static Future<void> deletePhoto(String entryId, EntryPhoto photo) async {
    try {
      await PhotoService.removeFromStorage([photo.storagePath]);
      await supabase.from('media').delete().eq('id', photo.id);
    } finally {
      notifyEntriesChanged();
    }
  }

  /// Sets [mediaId] as the cover photo for [entryId].
  static Future<void> setCoverPhoto(String entryId, String mediaId) async {
    try {
      await supabase
          .from('media')
          .update({'is_cover': false})
          .eq('entry_id', entryId);
      final updated = await supabase
          .from('media')
          .update({'is_cover': true})
          .eq('id', mediaId)
          .select('id');
      if (updated.isEmpty) {
        throw StateError('Could not update media row (check media UPDATE RLS policy).');
      }
      await supabase
          .from('entries')
          .update({'cover_media_id': mediaId})
          .eq('id', entryId);
    } finally {
      notifyEntriesChanged();
    }
  }

  /// Clears the cover photo selection for [entryId].
  static Future<void> clearCoverPhoto(String entryId) async {
    try {
      await supabase
          .from('media')
          .update({'is_cover': false})
          .eq('entry_id', entryId);
      await supabase
          .from('entries')
          .update({'cover_media_id': null})
          .eq('id', entryId);
    } finally {
      notifyEntriesChanged();
    }
  }

  /// Persists the new [ordered] photo sequence in `media.sort_order`.
  static Future<void> reorderPhotos(
    String entryId,
    List<EntryPhoto> ordered,
  ) async {
    try {
      for (var i = 0; i < ordered.length; i++) {
        final updated = await supabase
            .from('media')
            .update({'sort_order': i})
            .eq('id', ordered[i].id)
            .select('id');
        if (updated.isEmpty) {
          throw StateError('Could not update photo order (check media UPDATE RLS policy).');
        }
      }
    } finally {
      notifyEntriesChanged();
    }
  }

  /// Soft-deletes a memory by setting `deleted_at`. Storage files are kept so
  /// the deletion can be undone or restored from Recently Deleted.
  static Future<void> softDelete(String id) async {
    try {
      await supabase
          .from('entries')
          .update({'deleted_at': isoTimestamp(DateTime.now())})
          .eq('id', id);
    } finally {
      notifyEntriesChanged();
    }
  }

  /// Restores a soft-deleted memory.
  static Future<void> restore(String id) async {
    try {
      await supabase
          .from('entries')
          .update({'deleted_at': null})
          .eq('id', id);
    } finally {
      notifyEntriesChanged();
    }
  }

  /// Permanently deletes the photos from storage first, then the entry row.
  static Future<void> permanentlyDelete(
    String id,
    List<String> photoPaths,
  ) async {
    try {
      await PhotoService.removeFromStorage(photoPaths);
      await supabase.from('entries').delete().eq('id', id);
    } finally {
      notifyEntriesChanged();
    }
  }
}
