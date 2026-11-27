import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/models/album_choice.dart';
import 'package:aletheia_dev/core/services/album_service.dart';
import 'package:aletheia_dev/core/services/entry_service.dart';
import 'package:aletheia_dev/core/state/entries_revision.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/features/albums/album_form_sheet.dart';
import 'package:aletheia_dev/features/entry/entry_detail_page.dart';
import 'package:aletheia_dev/features/entry/entry_form_page.dart';
import 'package:aletheia_dev/widgets/app_snack_bar.dart';
import 'package:aletheia_dev/widgets/confirm_dialog.dart';
import 'package:aletheia_dev/widgets/empty_state.dart';
import 'package:aletheia_dev/widgets/memory_card.dart';
import 'package:aletheia_dev/widgets/skeleton.dart';

/// Shows an album's details and the grid of memories inside it.
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

  Future<void> _addMemoryToAlbum() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EntryFormPage(initialAlbum: _album),
      ),
    );
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
            tooltip: 'Add memory to album',
            icon: const Icon(Icons.add),
            onPressed: _busy ? null : _addMemoryToAlbum,
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
                ? const SkeletonMemoryGrid()
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
                                'Add a new memory or assign an existing one to "${_album.title}".',
                            actionLabel: 'Add Memory',
                            onAction: _addMemoryToAlbum,
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: GridView.builder(
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
