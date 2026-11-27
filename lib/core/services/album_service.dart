import 'package:aletheia_dev/core/models/album_choice.dart';
import 'package:aletheia_dev/core/services/photo_service.dart';
import 'package:aletheia_dev/core/services/supabase_client.dart';
import 'package:aletheia_dev/core/state/entries_revision.dart';

/// Reads and writes `albums` rows and resolves their cover thumbnails and
/// memory counts.
abstract final class AlbumService {
  /// Fetches all albums for the current user, newest first, with entry counts
  /// and signed cover thumbnail URLs.
  static Future<List<AlbumChoice>> fetchAll() async {
    final albumRows = await supabase
        .from('albums')
        .select('id, title, description, cover_media_id, created_at')
        .order('created_at', ascending: false);

    final albums = List<Map<String, dynamic>>.from(albumRows);
    if (albums.isEmpty) return const [];

    // Fetch active entries belonging to any album to compute counts & covers.
    final entryRows = await supabase
        .from('entries')
        .select(
          'id, album_id, cover_media_id, happened_at, media!media_entry_id_fkey(id, storage_path, sort_order, is_cover)',
        )
        .isFilter('deleted_at', null)
        .not('album_id', 'is', null)
        .order('happened_at', ascending: false);

    final counts = <String, int>{};
    final fallbackCoverByAlbum = <String, String>{};

    for (final e in entryRows) {
      final albumId = e['album_id'] as String?;
      if (albumId == null) continue;
      counts[albumId] = (counts[albumId] ?? 0) + 1;

      if (!fallbackCoverByAlbum.containsKey(albumId)) {
        final media = List<Map<String, dynamic>>.from(
          (e['media'] as List?) ?? const [],
        );
        final path = _pickCoverPath(e['cover_media_id'] as String?, media);
        if (path != null) fallbackCoverByAlbum[albumId] = path;
      }
    }

    final coverPaths = <String>[];
    final pathIndexByAlbum = <int, int>{};
    for (var i = 0; i < albums.length; i++) {
      final id = albums[i]['id'] as String;
      final path = fallbackCoverByAlbum[id];
      if (path != null) {
        pathIndexByAlbum[i] = coverPaths.length;
        coverPaths.add(path);
      }
    }

    final urls = await PhotoService.signedUrls(coverPaths, thumbnail: true);

    return [
      for (var i = 0; i < albums.length; i++)
        AlbumChoice(
          id: albums[i]['id'] as String,
          title: albums[i]['title'] as String,
          description: albums[i]['description'] as String?,
          coverPath: pathIndexByAlbum[i] == null
              ? null
              : coverPaths[pathIndexByAlbum[i]!],
          coverUrl:
              pathIndexByAlbum[i] == null ? null : urls[pathIndexByAlbum[i]!],
          entryCount: counts[albums[i]['id'] as String] ?? 0,
        ),
    ];
  }

  /// Lightweight list of albums for pickers/dropdowns.
  static Future<List<AlbumChoice>> fetchChoices() async {
    final rows = await supabase
        .from('albums')
        .select('id, title, description')
        .order('title', ascending: true);
    return [for (final r in rows) AlbumChoice.fromMap(r)];
  }

  static Future<AlbumChoice> create({
    required String title,
    String? description,
  }) async {
    try {
      final inserted = await supabase
          .from('albums')
          .insert({
            'title': title,
            'description': description,
          })
          .select('id, title, description')
          .single();
      return AlbumChoice.fromMap(inserted);
    } finally {
      notifyEntriesChanged();
    }
  }

  static Future<AlbumChoice> update({
    required String id,
    required String title,
    String? description,
  }) async {
    try {
      final updated = await supabase
          .from('albums')
          .update({
            'title': title,
            'description': description,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .select('id, title, description')
          .single();
      return AlbumChoice.fromMap(updated);
    } finally {
      notifyEntriesChanged();
    }
  }

  static Future<void> delete(String id) async {
    try {
      await supabase.from('albums').delete().eq('id', id);
    } finally {
      notifyEntriesChanged();
    }
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
}
