import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import 'package:aletheia_dev/core/services/entry_service.dart';
import 'package:aletheia_dev/core/services/notification_service.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/core/utils/date_format.dart';
import 'package:aletheia_dev/widgets/app_snack_bar.dart';
import 'package:aletheia_dev/widgets/photo_source_sheet.dart';
import 'package:aletheia_dev/widgets/primary_button.dart';
import 'package:aletheia_dev/widgets/section_card.dart';
import 'package:aletheia_dev/widgets/skeleton.dart';

/// "Your Moment has Ended!" prompt screen: pre-selects device photos taken
/// during the event's time window and lets the user upload or snooze.
class MomentEndedPromptPage extends StatefulWidget {
  const MomentEndedPromptPage({
    super.key,
    this.entry,
    this.entryId,
  }) : assert(entry != null || entryId != null);

  final Map<String, dynamic>? entry;
  final String? entryId;

  @override
  State<MomentEndedPromptPage> createState() => _MomentEndedPromptPageState();
}

class _MomentEndedPromptPageState extends State<MomentEndedPromptPage> {
  Map<String, dynamic>? _entry;
  bool _loadingEntry = true;

  bool _scanningPhotos = true;
  bool _permissionDenied = false;
  List<AssetEntity> _suggestedAssets = const [];
  final Set<String> _selectedAssetIds = {};
  List<XFile> _extraPhotos = [];

  bool _saving = false;
  int _uploadDone = 0;
  int _uploadTotal = 0;

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      _entry = Map<String, dynamic>.from(widget.entry!);
      _loadingEntry = false;
      _scanWindowPhotos();
    } else {
      _loadEntry();
    }
  }

  Future<void> _loadEntry() async {
    try {
      final fetched = await EntryService.fetchById(widget.entryId!);
      if (!mounted) return;
      if (fetched == null) {
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _entry = fetched;
        _loadingEntry = false;
      });
      await _scanWindowPhotos();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'Could not load moment: $e');
      Navigator.of(context).pop();
    }
  }

  Future<void> _scanWindowPhotos() async {
    final entry = _entry;
    if (entry == null) return;

    final start = tryParseEntryDate(entry['happened_at']) ?? DateTime.now();
    final end = tryParseEntryDate(entry['ends_at']) ?? DateTime.now();
    final minTime = start;
    final maxTime = end;

    try {
      final ps = await PhotoManager.requestPermissionExtend();
      if (!mounted) return;
      if (!ps.hasAccess) {
        setState(() {
          _permissionDenied = true;
          _scanningPhotos = false;
        });
        return;
      }

      final filterOption = FilterOptionGroup(
        createTimeCond: DateTimeCond(min: minTime, max: maxTime),
      );
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
        onlyAll: true,
        filterOption: filterOption,
      );
      if (paths.isEmpty) {
        if (!mounted) return;
        setState(() {
          _suggestedAssets = const [];
          _scanningPhotos = false;
        });
        return;
      }

      final assets = await paths.first.getAssetListPaged(page: 0, size: 30);
      if (!mounted) return;
      setState(() {
        _suggestedAssets = assets;
        _selectedAssetIds
          ..clear()
          ..addAll(assets.map((a) => a.id));
        _scanningPhotos = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _scanningPhotos = false);
    }
  }

  Future<void> _pickMorePhotos() async {
    final picked = await pickPhotos(context);
    if (picked.isEmpty || !mounted) return;
    setState(() => _extraPhotos = [..._extraPhotos, ...picked]);
  }

  Future<void> _uploadAndComplete() async {
    final entry = _entry;
    if (entry == null || _saving) return;
    final entryId = entry['id'] as String;

    setState(() {
      _saving = true;
      _uploadDone = 0;
      _uploadTotal = _selectedAssetIds.length + _extraPhotos.length;
    });

    try {
      final files = <XFile>[..._extraPhotos];
      for (final asset in _suggestedAssets) {
        if (!_selectedAssetIds.contains(asset.id)) continue;
        final file = await asset.file;
        if (file != null) files.add(XFile(file.path));
      }

      final result = await EntryService.completeUpcoming(
        entryId: entryId,
        photos: files,
        onUploadProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _uploadDone = done;
            _uploadTotal = total;
          });
        },
      );
      await NotificationService.cancelMoment(entryId);
      if (!mounted) return;

      if (result.hasFailures) {
        showAppSnackBar(
          context,
          'Moment saved, but ${result.failedFiles.length} photo(s) failed to upload.',
        );
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, 'Could not complete moment: $e');
    }
  }

  Future<void> _remindLater() async {
    final entry = _entry;
    if (entry == null || _saving) return;

    final duration = await showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    const Icon(Icons.schedule, color: AppColors.primary),
                title: const Text('In 1 hour'),
                onTap: () =>
                    Navigator.of(sheetCtx).pop(const Duration(hours: 1)),
              ),
              ListTile(
                leading:
                    const Icon(Icons.schedule, color: AppColors.primary),
                title: const Text('In 3 hours'),
                onTap: () =>
                    Navigator.of(sheetCtx).pop(const Duration(hours: 3)),
              ),
              ListTile(
                leading:
                    const Icon(Icons.wb_sunny_outlined, color: AppColors.primary),
                title: const Text('Tomorrow'),
                onTap: () =>
                    Navigator.of(sheetCtx).pop(const Duration(days: 1)),
              ),
            ],
          ),
        ),
      ),
    );
    if (duration == null || !mounted) return;

    await NotificationService.scheduleMomentEnded(
      entryId: entry['id'] as String,
      title: entry['title'] as String,
      when: DateTime.now().add(duration),
    );
    if (!mounted) return;
    showAppSnackBar(context, 'Reminder rescheduled.');
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final entry = _entry;

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Memory Prompt')),
        body: _loadingEntry || entry == null
            ? const SkeletonList(itemCount: 3)
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: [
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: AppColors.primarySoft,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.celebration_outlined,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your Moment has Ended!',
                                    style: textTheme.titleMedium?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    entry['title'] as String,
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          '${displayDateTimeOf(entry['happened_at'])} – ${displayDateTimeOf(entry['ends_at'])}',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Photos from this moment',
                          style: textTheme.titleSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _saving ? null : _pickMorePhotos,
                        icon: const Icon(Icons.add_photo_alternate_outlined,
                            size: 18),
                        label: const Text('Browse'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_scanningPhotos)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 6,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                      ),
                      itemBuilder: (_, _) =>
                          const SkeletonBox(borderRadius: AppRadius.mdAll),
                    )
                  else if (_permissionDenied)
                    SectionCard(
                      child: Text(
                        'Photo library access was not granted. Use "Browse" above to pick photos manually.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else if (_suggestedAssets.isEmpty && _extraPhotos.isEmpty)
                    SectionCard(
                      child: Text(
                        'No photos found in this time window. Tap "Browse" to add photos manually, or save without photos.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _suggestedAssets.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                      ),
                      itemBuilder: (context, index) {
                        final asset = _suggestedAssets[index];
                        final selected = _selectedAssetIds.contains(asset.id);
                        return GestureDetector(
                          onTap: _saving
                              ? null
                              : () => setState(() {
                                    if (selected) {
                                      _selectedAssetIds.remove(asset.id);
                                    } else {
                                      _selectedAssetIds.add(asset.id);
                                    }
                                  }),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: AppRadius.mdAll,
                                child: _AssetThumb(asset: asset),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: selected
                                      ? AppColors.primary
                                      : Colors.black45,
                                  child: Icon(
                                    selected ? Icons.check : Icons.circle_outlined,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  if (_extraPhotos.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '+ ${_extraPhotos.length} additional photo(s) selected',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (_saving && _uploadTotal > 0) ...[
                    const SizedBox(height: AppSpacing.lg),
                    LinearProgressIndicator(value: _uploadDone / _uploadTotal),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Uploading photo $_uploadDone of $_uploadTotal...',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Upload Photos & Save Memory',
                    loading: _saving,
                    onPressed: _uploadAndComplete,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: _saving ? null : _remindLater,
                    child: const Text('Remind Me Later'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AssetThumb extends StatefulWidget {
  const _AssetThumb({required this.asset});

  final AssetEntity asset;

  @override
  State<_AssetThumb> createState() => _AssetThumbState();
}

class _AssetThumbState extends State<_AssetThumb> {
  late final Future<Uint8List?> _future =
      widget.asset.thumbnailDataWithSize(const ThumbnailSize.square(250));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) {
          return const SkeletonBox(borderRadius: AppRadius.mdAll);
        }
        return Image.memory(bytes, fit: BoxFit.cover);
      },
    );
  }
}
