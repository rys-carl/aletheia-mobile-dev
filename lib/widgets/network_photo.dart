import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/theme/app_colors.dart';

/// A network image with a neutral placeholder, a fade-in, and a broken-image
/// fallback. Use for every photo that comes from storage.
class NetworkPhoto extends StatelessWidget {
  const NetworkPhoto({
    super.key,
    required this.url,
    this.cacheWidth,
    this.fit = BoxFit.cover,
  });

  final String url;

  /// Decode the image at this width to save memory. Roughly the displayed
  /// width in pixels (2-3x the logical size).
  final int? cacheWidth;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceMuted,
      child: Image.network(
        url,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: cacheWidth,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            child: child,
          );
        },
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image_outlined, color: AppColors.textHint),
        ),
      ),
    );
  }
}
