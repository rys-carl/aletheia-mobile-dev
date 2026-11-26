import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/core/utils/date_format.dart';
import 'package:aletheia_dev/widgets/network_photo.dart';

/// Grid card for one memory: cover photo, title, and date · place.
/// Expects the map produced by `EntryService.fetchAll()`.
class MemoryCard extends StatelessWidget {
  const MemoryCard({super.key, required this.entry, required this.onTap});

  final Map<String, dynamic> entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final thumb = entry['thumb_url'] as String?;
    final thumbPath = entry['thumb_path'] as String?;
    final count = (entry['photo_count'] as int?) ?? 0;
    final place = entry['places'] as Map<String, dynamic>?;
    final date = displayDateOf(entry['happened_at']);
    final subtitle = place == null ? date : '$date · ${place['name']}';

    return Container(
      decoration: const BoxDecoration(
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: AppRadius.mdAll,
                        child: thumb == null
                            ? const _NoPhoto()
                            : NetworkPhoto(
                                url: thumb,
                                storagePath: thumbPath,
                                thumbnail: true,
                                cacheWidth: 400,
                              ),
                      ),
                      if (count > 1)
                        Positioned(
                          top: AppSpacing.sm,
                          right: AppSpacing.sm,
                          child: _CountBadge(count: count),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  entry['title'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoPhoto extends StatelessWidget {
  const _NoPhoto();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.primarySoft,
      child: Center(
        child: Icon(Icons.auto_stories_outlined, color: AppColors.primary),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: const BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_library_outlined, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
