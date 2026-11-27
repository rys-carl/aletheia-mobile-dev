import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/services/photo_service.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/widgets/skeleton.dart';

/// A disk-cached network image with fade-in, optional thumbnail cache key, and
/// automatic signed-URL refresh when a 1-hour link expires.
class NetworkPhoto extends StatefulWidget {
  const NetworkPhoto({
    super.key,
    required this.url,
    this.storagePath,
    this.thumbnail = false,
    this.cacheWidth,
    this.fit = BoxFit.cover,
  });

  final String url;

  /// Stable storage path used as the disk cache key and to refresh expired
  /// signed URLs.
  final String? storagePath;

  /// Whether [url] is a transformed thumbnail (keeps thumbnail and full-res
  /// cache entries separate).
  final bool thumbnail;

  /// Decode the image at this width to save memory. Roughly the displayed
  /// width in pixels (2-3x the logical size).
  final int? cacheWidth;
  final BoxFit fit;

  @override
  State<NetworkPhoto> createState() => _NetworkPhotoState();
}

class _NetworkPhotoState extends State<NetworkPhoto> {
  late String _currentUrl;
  bool _retried = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
  }

  @override
  void didUpdateWidget(NetworkPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.storagePath != widget.storagePath) {
      _currentUrl = widget.url;
      _retried = false;
      _refreshing = false;
    }
  }

  String? get _cacheKey {
    final path = widget.storagePath;
    if (path == null || path.isEmpty) return null;
    return widget.thumbnail ? '${path}_thumb' : path;
  }

  Future<void> _refreshSignedUrl() async {
    final path = widget.storagePath;
    if (path == null || path.isEmpty || _refreshing) return;
    setState(() => _refreshing = true);
    try {
      final fresh = await PhotoService.signedUrl(
        path,
        thumbnail: widget.thumbnail,
      );
      if (!mounted) return;
      setState(() {
        _currentUrl = fresh;
        _retried = true;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _retried = true;
        _refreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_refreshing) {
      return const SkeletonBox(
        width: double.infinity,
        height: double.infinity,
        borderRadius: BorderRadius.zero,
      );
    }

    if (_currentUrl.isEmpty) {
      if (widget.storagePath != null && !_retried) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _refreshSignedUrl();
        });
      }
      return const ColoredBox(
        color: AppColors.surfaceMuted,
        child: Center(
          child: Icon(Icons.broken_image_outlined, color: AppColors.textHint),
        ),
      );
    }

    return ColoredBox(
      color: AppColors.surfaceMuted,
      child: CachedNetworkImage(
        imageUrl: _currentUrl,
        cacheKey: _cacheKey,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: widget.cacheWidth,
        fadeInDuration: const Duration(milliseconds: 250),
        placeholder: (context, url) =>
            const ColoredBox(color: AppColors.surfaceMuted),
        errorWidget: (context, url, error) {
          if (widget.storagePath != null && !_retried) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _refreshSignedUrl();
            });
            return const ColoredBox(color: AppColors.surfaceMuted);
          }
          return GestureDetector(
            onTap: widget.storagePath == null
                ? null
                : () {
                    _retried = false;
                    _refreshSignedUrl();
                  },
            child: const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: AppColors.textHint,
              ),
            ),
          );
        },
      ),
    );
  }
}
