import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/models/entry_photo.dart';
import 'package:aletheia_dev/core/services/entry_service.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/widgets/confirm_dialog.dart';
import 'package:aletheia_dev/widgets/network_photo.dart';

/// Opens a bottom sheet to reorder photos, choose a cover photo, or delete
/// individual photos for [entryId]. Returns the updated photo list when closed.
Future<List<EntryPhoto>> showPhotoManagerSheet(
  BuildContext context, {
  required String entryId,
  required List<EntryPhoto> photos,
}) async {
  final result = await showModalBottomSheet<List<EntryPhoto>>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    useSafeArea: true,
    builder: (_) => _PhotoManagerSheet(entryId: entryId, initialPhotos: photos),
  );
  return result ?? photos;
}

class _PhotoManagerSheet extends StatefulWidget {
  const _PhotoManagerSheet({
    required this.entryId,
    required this.initialPhotos,
  });

  final String entryId;
  final List<EntryPhoto> initialPhotos;

  @override
  State<_PhotoManagerSheet> createState() => _PhotoManagerSheetState();
}

class _PhotoManagerSheetState extends State<_PhotoManagerSheet> {
  late List<EntryPhoto> _photos;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _photos = List<EntryPhoto>.from(widget.initialPhotos);
  }

  Future<void> _toggleCover(EntryPhoto photo) async {
    if (_busy) return;
    final selecting = !photo.isCover;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (selecting) {
        await EntryService.setCoverPhoto(widget.entryId, photo.id);
      } else {
        await EntryService.clearCoverPhoto(widget.entryId);
      }
      if (!mounted) return;
      setState(() {
        _photos = [
          for (final p in _photos)
            p.copyWith(isCover: selecting && p.id == photo.id),
        ];
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not update cover photo: $e';
      });
    }
  }

  Future<void> _deletePhoto(EntryPhoto photo) async {
    if (_busy) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Photo?',
      message: 'This photo will be permanently removed from this memory.',
      confirmLabel: 'Delete Photo',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await EntryService.deletePhoto(widget.entryId, photo);
      if (!mounted) return;
      final remaining = _photos.where((p) => p.id != photo.id).toList();
      if (photo.isCover && remaining.isNotEmpty) {
        await EntryService.setCoverPhoto(widget.entryId, remaining.first.id);
        remaining[0] = remaining[0].copyWith(isCover: true);
      }
      if (!mounted) return;
      setState(() {
        _photos = remaining;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not delete photo: $e';
      });
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (_busy) return;
    final previous = List<EntryPhoto>.from(_photos);
    setState(() {
      final item = _photos.removeAt(oldIndex);
      _photos.insert(newIndex, item);
      _busy = true;
      _error = null;
    });

    try {
      await EntryService.reorderPhotos(widget.entryId, _photos);
      if (!mounted) return;
      setState(() {
        _photos = [
          for (var i = 0; i < _photos.length; i++)
            _photos[i].copyWith(sortOrder: i),
        ];
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _photos = previous;
        _busy = false;
        _error = 'Could not reorder photos: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_photos);
      },
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Photos',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Drag handle to reorder · Tap star for cover',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context, _photos),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Container(
                width: double.infinity,
                color: AppColors.danger.withValues(alpha: 0.1),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  _error!,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: _photos.isEmpty
                  ? Center(
                      child: Text(
                        'No photos left.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: _photos.length,
                      onReorderItem: _onReorder,
                      itemBuilder: (context, index) {
                        final photo = _photos[index];
                        return ListTile(
                          key: ValueKey(photo.id),
                          leading: ReorderableDelayedDragStartListener(
                            index: index,
                            child: SizedBox(
                              width: 56,
                              height: 56,
                              child: ClipRRect(
                                borderRadius: AppRadius.smAll,
                                child: NetworkPhoto(
                                  url: photo.url,
                                  storagePath: photo.storagePath,
                                  cacheWidth: 200,
                                ),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                'Photo ${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (photo.isCover) ...[
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Cover Photo',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: photo.isCover
                                    ? 'Remove cover photo'
                                    : 'Set as cover',
                                onPressed:
                                    _busy ? null : () => _toggleCover(photo),
                                icon: Icon(
                                  photo.isCover
                                      ? Icons.star
                                      : Icons.star_outline,
                                  color: photo.isCover
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Delete photo',
                                onPressed:
                                    _busy ? null : () => _deletePhoto(photo),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.danger,
                                ),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.all(AppSpacing.sm),
                                  child: Icon(
                                    Icons.drag_handle,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
