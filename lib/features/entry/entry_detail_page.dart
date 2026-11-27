import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:aletheia_dev/core/models/album_choice.dart';
import 'package:aletheia_dev/core/models/entry_photo.dart';
import 'package:aletheia_dev/core/models/place_choice.dart';
import 'package:aletheia_dev/core/services/entry_service.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/core/utils/date_format.dart';
import 'package:aletheia_dev/features/albums/album_detail_page.dart';
import 'package:aletheia_dev/features/entry/entry_form_page.dart';
import 'package:aletheia_dev/features/upcoming/moment_ended_prompt_page.dart';
import 'package:aletheia_dev/widgets/app_snack_bar.dart';
import 'package:aletheia_dev/widgets/confirm_dialog.dart';
import 'package:aletheia_dev/widgets/feeling_picker.dart';
import 'package:aletheia_dev/widgets/network_photo.dart';
import 'package:aletheia_dev/widgets/photo_manager_sheet.dart';
import 'package:aletheia_dev/widgets/photo_source_sheet.dart';
import 'package:aletheia_dev/widgets/photo_viewer.dart';
import 'package:aletheia_dev/widgets/primary_button.dart';
import 'package:aletheia_dev/widgets/section_card.dart';
import 'package:aletheia_dev/widgets/skeleton.dart';

/// Shows one memory: hero photo, photo strip with management & upload
/// progress/retry, details with date & time, and soft-delete.
class EntryDetailPage extends StatefulWidget {
  const EntryDetailPage({super.key, required this.entry});

  final Map<String, dynamic> entry;

  @override
  State<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends State<EntryDetailPage> {
  late Map<String, dynamic> _entry;

  List<EntryPhoto> _photos = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  int _uploadDone = 0;
  int _uploadTotal = 0;
  List<XFile> _failedUploads = const [];

  String get _id => _entry['id'] as String;

  PlaceChoice? get _place {
    final p = _entry['places'];
    return p is Map<String, dynamic> ? PlaceChoice.fromMap(p) : null;
  }

  AlbumChoice? get _album {
    final a = _entry['albums'];
    return a is Map<String, dynamic> ? AlbumChoice.fromMap(a) : null;
  }

  EntryPhoto? get _coverPhoto {
    if (_photos.isEmpty) return null;
    for (final p in _photos) {
      if (p.isCover) return p;
    }
    return _photos.first;
  }

  @override
  void initState() {
    super.initState();
    _entry = Map.of(widget.entry);
    _loadPhotos();
  }

  void _showError(String message) {
    if (!mounted) return;
    showAppSnackBar(context, message);
  }

  Future<void> _loadPhotos() async {
    try {
      final photos = await EntryService.loadPhotos(_id);
      if (!mounted) return;
      setState(() {
        _photos = photos;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => EntryFormPage(entry: _entry, existingPhotos: _photos),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _entry = {..._entry, ...updated});
    await _loadPhotos();
  }

  Future<void> _managePhotos() async {
    final updated = await showPhotoManagerSheet(
      context,
      entryId: _id,
      photos: _photos,
    );
    if (!mounted) return;
    setState(() => _photos = updated);
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Memory?',
      message:
          'This memory will be moved to Recently Deleted. You can undo or restore it later.',
      confirmLabel: 'Delete Memory',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await EntryService.softDelete(_id);
      if (!mounted) return;
      Navigator.of(context).pop(_id);
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError('Could not delete: $e');
    }
  }

  Future<void> _addPhotos() async {
    final picked = await pickPhotos(context);
    if (picked.isEmpty || !mounted) return;
    await _uploadFiles(picked);
  }

  Future<void> _uploadFiles(List<XFile> files) async {
    setState(() {
      _busy = true;
      _uploadDone = 0;
      _uploadTotal = files.length;
      _failedUploads = const [];
    });

    try {
      final result = await EntryService.addPhotos(
        _id,
        files,
        startSortOrder: _photos.length,
        onUploadProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _uploadDone = done;
            _uploadTotal = total;
          });
        },
      );
      await _loadPhotos();
      if (!mounted) return;
      if (result.hasFailures) {
        setState(() => _failedUploads = result.failedFiles);
        showAppSnackBar(
          context,
          '${result.failedFiles.length} photo(s) failed to upload.',
          actionLabel: 'Retry',
          onAction: () => _uploadFiles(_failedUploads),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _failedUploads = files);
      _showError('Could not upload photos: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _uploadTotal = 0;
        });
      }
    }
  }

  void _openViewer(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhotoViewer(
          urls: [for (final p in _photos) p.url],
          storagePaths: [for (final p in _photos) p.storagePath],
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Details'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _edit,
            child: const Text('Edit'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Column(
        children: [
          if (_busy)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: _uploadTotal > 0 ? _uploadDone / _uploadTotal : null,
                ),
                if (_uploadTotal > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      'Uploading photo $_uploadDone of $_uploadTotal...',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
              ],
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: [
                _buildHero(),
                if (_failedUploads.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _FailedUploadBanner(
                    count: _failedUploads.length,
                    onRetry: _busy ? null : () => _uploadFiles(_failedUploads),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                _buildPhotosCard(),
                const SizedBox(height: AppSpacing.lg),
                _buildDetailsCard(),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Delete Memory',
                  destructive: true,
                  onPressed: _busy ? null : _delete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    final cover = _coverPhoto;
    final coverIndex = cover == null ? 0 : _photos.indexOf(cover);
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: ClipRRect(
        borderRadius: AppRadius.lgAll,
        child: cover == null
            ? (_loading
                ? const SkeletonBox(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: BorderRadius.zero,
                  )
                : const ColoredBox(
                    color: AppColors.primarySoft,
                    child: Center(
                      child: Icon(
                        Icons.photo_outlined,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                  ))
            : GestureDetector(
                onTap: () => _openViewer(coverIndex < 0 ? 0 : coverIndex),
                child: NetworkPhoto(
                  url: cover.url,
                  storagePath: cover.storagePath,
                  cacheWidth: 1000,
                ),
              ),
      ),
    );
  }

  Widget _buildPhotosCard() {
    final textTheme = Theme.of(context).textTheme;

    Widget content;
    if (_loading) {
      content = const SkeletonPhotoStrip();
    } else if (_error != null) {
      content = Text('Could not load photos:\n$_error');
    } else if (_photos.isEmpty) {
      content = Text(
        'No photos yet.',
        style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      );
    } else {
      content = SizedBox(
        height: 88,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _photos.length,
          separatorBuilder: (context, index) =>
              const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, index) {
            final photo = _photos[index];
            return GestureDetector(
              onTap: () => _openViewer(index),
              child: SizedBox(
                width: 88,
                child: ClipRRect(
                  borderRadius: AppRadius.mdAll,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      NetworkPhoto(
                        url: photo.url,
                        storagePath: photo.storagePath,
                        cacheWidth: 300,
                      ),
                      if (photo.isCover)
                        const Positioned(
                          left: 4,
                          bottom: 4,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black54,
                            child: Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Photos',
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_photos.isNotEmpty)
                TextButton.icon(
                  onPressed: _busy ? null : _managePhotos,
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Manage'),
                ),
              TextButton.icon(
                onPressed: _busy ? null : _addPhotos,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          content,
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    final textTheme = Theme.of(context).textTheme;
    final note = _entry['note'] as String?;
    final feeling = _entry['feeling'] as String?;
    final isUpcoming = _entry['type'] == 'upcoming';
    final startsAt = tryParseEntryDate(_entry['happened_at']);
    final endsAt = tryParseEntryDate(_entry['ends_at']);
    final now = DateTime.now();
    final hasEnded = endsAt != null && !endsAt.isAfter(now);
    final hasStarted =
        !hasEnded && startsAt != null && !startsAt.isAfter(now);
    final place = _place;
    final album = _album;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _entry['title'] as String,
            style: textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(note, style: textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (isUpcoming) ...[
            _InfoRow(
              label: 'Status:',
              value: hasEnded
                  ? 'Ended · Ready for photos'
                  : hasStarted
                      ? 'Happening now'
                      : 'Upcoming',
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          _InfoRow(
            label: isUpcoming ? 'Starts:' : 'Date & Time:',
            value: displayDateTimeOf(_entry['happened_at']),
          ),
          if (isUpcoming && _entry['ends_at'] != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(
              label: 'Ends:',
              value: displayDateTimeOf(_entry['ends_at']),
            ),
          ],
          if (feeling != null && feeling.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(label: 'Feeling:', value: formatFeeling(feeling)),
          ],
          if (place != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(label: 'Location:', value: place.name),
          ],
          if (album != null) ...[
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AlbumDetailPage(album: album),
                ),
              ),
              child: _InfoRow(
                label: 'Album:',
                value: album.title,
                isLink: true,
              ),
            ),
          ],
          if (isUpcoming && hasEnded) ...[
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Upload Photos & Complete',
              onPressed: () async {
                final completed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => MomentEndedPromptPage(entry: _entry),
                  ),
                );
                if (completed == true && mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _FailedUploadBanner extends StatelessWidget {
  const _FailedUploadBanner({required this.count, required this.onRetry});

  final int count;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.danger.withValues(alpha: 0.08),
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '$count photo${count == 1 ? '' : 's'} failed to upload.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isLink = false,
  });

  final String label;
  final String value;
  final bool isLink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: isLink ? AppColors.primary : null,
              decoration: isLink ? TextDecoration.underline : null,
            ),
          ),
        ),
      ],
    );
  }
}
