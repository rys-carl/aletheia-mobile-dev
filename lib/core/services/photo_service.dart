import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:aletheia_dev/core/config/app_config.dart';
import 'package:aletheia_dev/core/services/supabase_client.dart';

/// Photo storage: uploads, signed (temporary) links, and removal.
abstract final class PhotoService {
  /// Uploads photos to the private bucket and records each one in the
  /// `media` table. Files go in <user_id>/<entry_id>/..., which is the folder
  /// pattern the storage security policy requires.
  static Future<void> upload(String entryId, List<XFile> photos) async {
    if (photos.isEmpty) return;
    final userId = supabase.auth.currentUser!.id;
    for (final photo in photos) {
      final bytes = await photo.readAsBytes();
      final ext = _extensionOf(photo.name);
      final path =
          '$userId/$entryId/${DateTime.now().microsecondsSinceEpoch}.$ext';
      await supabase.storage.from(AppConfig.photoBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: _mimeFor(ext)),
          );
      await supabase.from('media').insert({
        'entry_id': entryId,
        'storage_path': path,
      });
    }
  }

  /// Temporary links for private photos, in the same order as [paths].
  static Future<List<String>> signedUrls(
    List<String> paths, {
    int seconds = 3600,
  }) async {
    if (paths.isEmpty) return [];
    final signed = await supabase.storage
        .from(AppConfig.photoBucket)
        .createSignedUrls(paths, seconds);
    return [for (final s in signed) s.signedUrl];
  }

  static Future<void> removeFromStorage(List<String> paths) async {
    if (paths.isEmpty) return;
    await supabase.storage.from(AppConfig.photoBucket).remove(paths);
  }

  static String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return 'jpg';
    return name.substring(dot + 1).toLowerCase();
  }

  static String _mimeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }
}
