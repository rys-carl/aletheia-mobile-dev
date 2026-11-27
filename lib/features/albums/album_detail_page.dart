import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/models/album_choice.dart';
import 'package:aletheia_dev/core/services/album_service.dart';
import 'package:aletheia_dev/core/services/entry_service.dart';
import 'package:aletheia_dev/core/state/entries_revision.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/core/utils/date_format.dart';
import 'package:aletheia_dev/features/albums/album_form_sheet.dart';
import 'package:aletheia_dev/features/entry/entry_detail_page.dart';
import 'package:aletheia_dev/features/entry/entry_form_page.dart';
import 'package:aletheia_dev/widgets/app_snack_bar.dart';
import 'package:aletheia_dev/widgets/confirm_dialog.dart';
import 'package:aletheia_dev/widgets/empty_state.dart';
import 'package:aletheia_dev/widgets/memory_card.dart';
import 'package:aletheia_dev/widgets/memory_list_tile.dart';
import 'package:aletheia_dev/widgets/network_photo.dart';
import 'package:aletheia_dev/widgets/primary_button.dart';
import 'package:aletheia_dev/widgets/skeleton.dart';

/// Shows an album's details and the memories inside it (card grid or compact
/// list view).
class AlbumDetailPage extends StatefulWidget {
  const AlbumDetailPage({super.key, required this.album});

  final AlbumChoice album;

  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  late AlbumChoice _album;
  List<Map<String, dynamic>>? _entries;
  Object? _error;
  bool _loading = true;
  bool _busy = false;
  bool _compactList = false;

  @override
  void initState() {
    super.initState();
    _album = widget.album;
    entriesRevision.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    entriesRevision.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => _load();

  Future<void> _load() async {
    try {
      final data = await EntryService.fetchPage(
        page: 0,
        pageSize: 100,
        albumId: _album.id,
      );
      if (!mounted) return;
      setState(() {
        _entries = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _editAlbum() async {
    final updated = await showAlbumFormSheet(context, album: _album);
    if (updated == null || !mounted) return;
    setState(() => _album = updated);
  }

  Future<void> _deleteAlbum() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Album?',
      message:
          'Memories inside this album will not be deleted — they will simply be ungrouped.',
      confirmLabel: 'Delete Album',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await AlbumService.delete(_album.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppSnackBar(context, 'Could not delete album: $e');
    }
  }

  Future<void> _createMemoryInAlbum() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EntryFormPage(initialAlbum: _album),
      ),
    );
  }

  Future<void> _openAddMemoriesSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _AddExistingMemoriesSheet(
        album: _album,
        onCreateNew: _createMemoryInAlbum,
      ),
    );
    if (added == true && mounted) {
      showAppSnackBar(context, 'Added to "${_album.title}"');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final entries = _entries;

    return Scaffold(
      appBar: AppBar(
        title: Text(_album.title),
        actions: [
          IconButton(
            tooltip: _compactList ? 'Card view' : 'Compact list view',
            icon: Icon(
              _compactList
                  ? Icons.grid_view_outlined
                  : Icons.view_list_outlined,
            ),
            onPressed: () => setState(() => _compactList = !_compactList),
          ),
          IconButton(
            tooltip: 'Add memories to album',
            icon: const Icon(Icons.add),
            onPressed: _busy ? null : _openAddMemoriesSheet,
          ),
          PopupMenuButton<String>(
            enabled: !_busy,
            onSelected: (value) {
              if (value == 'edit') _editAlbum();
              if (value == 'delete') _deleteAlbum();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit album')),
              PopupMenuItem(value: 'delete', child: Text('Delete album')),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_album.description != null && _album.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                _album.description!,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          Expanded(
            child: _loading && entries == null
                ? (_compactList
                    ? const SkeletonList()
                    : const SkeletonMemoryGrid())
                : _error != null && entries == null
                    ? EmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Could not load album',
                        message: '$_error',
                        actionLabel: 'Try again',
                        onAction: () {
                          setState(() => _loading = true);
                          _load();
                        },
                      )
                    : (entries == null || entries.isEmpty)
                        ? EmptyState(
                            icon: Icons.photo_album_outlined,
                            title: 'No memories yet',
                            message:
                                'Create a new memory or assign an existing one to "${_album.title}".',
                            actionLabel: 'Create Memory',
                            onAction: _createMemoryInAlbum,
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: _compactList
                                ? ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      AppSpacing.lg,
                                      AppSpacing.sm,
                                      AppSpacing.lg,
                                      AppSpacing.xl,
                                    ),
                                    itemCount: entries.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: AppSpacing.sm),
                                    itemBuilder: (context, index) {
                                      final entry = entries[index];
                                      return MemoryListTile(
                                        entry: entry,
                                        onTap: () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                EntryDetailPage(entry: entry),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      AppSpacing.lg,
                                      AppSpacing.sm,
                                      AppSpacing.lg,
                                      AppSpacing.xl,
                                    ),
                                    itemCount: entries.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: AppSpacing.md,
                                      crossAxisSpacing: AppSpacing.md,
                                      childAspectRatio: 0.78,
                                    ),
                                    itemBuilder: (context, index) {
                                      final entry = entries[index];
                                      return MemoryCard(
                                        entry: entry,
                                        onTap: () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                EntryDetailPage(entry: entry),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _AddExistingMemoriesSheet extends StatefulWidget {
  const _AddExistingMemoriesSheet({
    required this.album,
    required this.onCreateNew,
  });

  final AlbumChoice album;
  final VoidCallback onCreateNew;

  @override
  State<_AddExistingMemoriesSheet> createState() =>
      _AddExistingMemoriesSheetState();
}

class _AddExistingMemoriesSheetState extends State<_AddExistingMemoriesSheet> {
  List<Map<String, dynamic>>? _candidates;
  Object? _error;
  bool _loading = true;
  bool _saving = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await EntryService.fetchAssignableToAlbum(widget.album.id);
      if (!mounted) return;
      setState(() {
        _candidates = rows;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _assignSelected() async {
    if (_selectedIds.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await EntryService.assignToAlbum(
        _selectedIds.toList(),
        widget.album.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, 'Could not add memories: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final candidates = _candidates;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) => SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add to "${widget.album.title}"',
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            widget.onCreateNew();
                          },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create New'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const SkeletonList(itemCount: 4)
                  : _error != null
                      ? Center(child: Text('Could not load memories: $_error'))
                      : (candidates == null || candidates.isEmpty)
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(AppSpacing.xl),
                                child: Text(
                                  'All of your existing memories are already in this album.',
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(color: AppColors.textSecondary),
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: candidates.length,
                              itemBuilder: (_, i) {
                                final item = candidates[i];
                                final id = item['id'] as String;
                                final selected = _selectedIds.contains(id);
                                final thumb = item['thumb_url'] as String?;
                                final thumbPath = item['thumb_path'] as String?;
                                return CheckboxListTile(
                                  value: selected,
                                  onChanged: _saving
                                      ? null
                                      : (_) => setState(() {
                                            if (selected) {
                                              _selectedIds.remove(id);
                                            } else {
                                              _selectedIds.add(id);
                                            }
                                          }),
                                  secondary: ClipRRect(
                                    borderRadius: AppRadius.smAll,
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
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
                                              cacheWidth: 160,
                                            ),
                                    ),
                                  ),
                                  title: Text(
                                    item['title'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    displayDateOf(item['happened_at']),
                                    style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
            if (_selectedIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: PrimaryButton(
                  label:
                      'Add ${_selectedIds.length} ${_selectedIds.length == 1 ? 'Memory' : 'Memories'}',
                  loading: _saving,
                  onPressed: _assignSelected,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
