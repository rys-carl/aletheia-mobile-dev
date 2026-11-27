import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/core/utils/date_format.dart';
import 'package:aletheia_dev/widgets/network_photo.dart';

/// Compact horizontal list row for one memory: thumbnail, title, date · place,
/// optional feeling emoji, and photo count.
class MemoryListTile extends StatelessWidget {
  const MemoryListTile({
    super.key,
    required this.entry,
    required this.onTap,
  });

  final Map<String, dynamic> entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final thumb = entry['thumb_url'] as String?;
    final thumbPath = entry['thumb_path'] as String?;
    final count = (entry['photo_count'] as int?) ?? 0;
    final feeling = entry['feeling'] as String?;
    final place = entry['places'] as Map<String, dynamic>?;
    final date = displayDateOf(entry['happened_at']);
    final subtitle = place == null ? date : '$date · ${place['name']}';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.mdAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: AppRadius.smAll,
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: thumb == null
                        ? const ColoredBox(
                            color: AppColors.primarySoft,
                            child: Icon(
                              Icons.auto_stories_outlined,
                              color: AppColors.primary,
                            ),
                          )
                        : NetworkPhoto(
                            url: thumb,
                            storagePath: thumbPath,
                            thumbnail: true,
                            cacheWidth: 200,
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (feeling != null && feeling.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Text(feeling, style: const TextStyle(fontSize: 16)),
                ],
                if (count > 1) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Text(
                      '$count',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.chevron_right, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
