import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:aletheia_dev/core/config/app_config.dart';
import 'package:aletheia_dev/core/services/supabase_client.dart';

/// Result of uploading a batch of photos, tracking any failures for retry.
class UploadBatchResult {
  const UploadBatchResult({
    required this.uploadedCount,
    required this.failedFiles,
    this.firstError,
  });

  final int uploadedCount;
  final List<XFile> failedFiles;
  final Object? firstError;

  bool get hasFailures => failedFiles.isNotEmpty;
}

/// Photo storage: uploads with progress/retry, signed (temporary) links with
/// optional image transformations, and removal.
abstract final class PhotoService {
  static const TransformOptions _thumbTransform = TransformOptions(
    width: 400,
    height: 400,
    resize: ResizeMode.cover,
    quality: 75,
  );

  /// Uploads photos sequentially, reporting progress via [onProgress], and
  /// returns an [UploadBatchResult] containing any files that failed so the
  /// caller can offer a retry.
  ///
  /// Files are stored under `<user_id>/<entry_id>/...` as required by the
  /// storage security policy.
  static Future<UploadBatchResult> uploadWithProgress(
    String entryId,
    List<XFile> photos, {
    int startSortOrder = 0,
    void Function(int completed, int total)? onProgress,
  }) async {
    if (photos.isEmpty) {
      return const UploadBatchResult(uploadedCount: 0, failedFiles: []);
    }

    final userId = supabase.auth.currentUser!.id;
    final failed = <XFile>[];
    Object? firstError;
    var uploaded = 0;

    for (var i = 0; i < photos.length; i++) {
      final photo = photos[i];
      try {
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
          'sort_order': startSortOrder + i,
        });
        uploaded++;
      } catch (e) {
        failed.add(photo);
        firstError ??= e;
      } finally {
        onProgress?.call(i + 1, photos.length);
      }
    }

    return UploadBatchResult(
      uploadedCount: uploaded,
      failedFiles: failed,
      firstError: firstError,
    );
  }

  /// Temporary link for a single private photo. When [thumbnail] is true,
  /// requests a 400x400 Supabase image transformation (falling back to the
  /// original if image transformations are unavailable).
  static Future<String> signedUrl(
    String path, {
    int seconds = 3600,
    bool thumbnail = false,
  }) async {
    final bucket = supabase.storage.from(AppConfig.photoBucket);
    if (thumbnail) {
      try {
        return await bucket.createSignedUrl(
          path,
          seconds,
          transform: _thumbTransform,
        );
      } on StorageException {
        // Fall back to full-size signed URL if transformations aren't enabled.
      }
    }
    return bucket.createSignedUrl(path, seconds);
  }

  /// Temporary links for private photos, in the same order as [paths].
  static Future<List<String>> signedUrls(
    List<String> paths, {
    int seconds = 3600,
    bool thumbnail = false,
  }) async {
    if (paths.isEmpty) return [];

    if (thumbnail) {
      return Future.wait([
        for (final path in paths)
          signedUrl(path, seconds: seconds, thumbnail: true),
      ]);
    }

    final results = await supabase.storage
        .from(AppConfig.photoBucket)
        .createSignedUrlsResult(paths, seconds);

    final byPath = <String, String>{};
    for (final r in results) {
      if (r is SignedUrlSuccess) {
        byPath[r.path] = r.signedUrl;
      }
    }
    return [for (final p in paths) byPath[p] ?? ''];
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
