import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:aletheia_dev/core/models/entry_photo.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/widgets/network_photo.dart';

/// Horizontal strip used in the memory form: an "Add Photos" tile, then the
/// photos already saved ([existingPhotos], tappable via [onManageExisting]),
/// then photos picked but not saved yet ([pending], each with a remove button).
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({
    super.key,
    required this.onAdd,
    this.existingPhotos = const [],
    this.onManageExisting,
    this.pending = const [],
    this.onRemovePending,
  });

  final VoidCallback onAdd;
  final List<EntryPhoto> existingPhotos;
  final VoidCallback? onManageExisting;
  final List<XFile> pending;
  final void Function(int index)? onRemovePending;

  static const double _size = 104;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _size,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _AddTile(onTap: onAdd),
          for (final photo in existingPhotos)
            _Thumb(
              isCover: photo.isCover,
              onTap: onManageExisting,
              child: NetworkPhoto(
                url: photo.url,
                storagePath: photo.storagePath,
                cacheWidth: 300,
              ),
            ),
          for (var i = 0; i < pending.length; i++)
            _Thumb(
              onRemove: onRemovePending == null
                  ? null
                  : () => onRemovePending!(i),
              child: Image.file(
                File(pending[i].path),
                fit: BoxFit.cover,
                cacheWidth: 300,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: PhotoStrip._size,
            height: PhotoStrip._size,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.add, size: 18, color: AppColors.onPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Add Photos',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.child,
    this.onRemove,
    this.onTap,
    this.isCover = false,
  });

  final Widget child;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;
  final bool isCover;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        width: PhotoStrip._size,
        height: PhotoStrip._size,
        child: ClipRRect(
          borderRadius: AppRadius.mdAll,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(onTap: onTap, child: child),
              if (isCover)
                Positioned(
                  left: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 11, color: Colors.amber),
                        SizedBox(width: 2),
                        Text(
                          'Cover',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (onRemove != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: const CircleAvatar(
                      radius: 11,
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
