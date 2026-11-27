import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/models/album_choice.dart';
import 'package:aletheia_dev/core/services/album_service.dart';
import 'package:aletheia_dev/core/state/entries_revision.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/features/albums/album_detail_page.dart';
import 'package:aletheia_dev/features/albums/album_form_sheet.dart';
import 'package:aletheia_dev/widgets/empty_state.dart';
import 'package:aletheia_dev/widgets/network_photo.dart';
import 'package:aletheia_dev/widgets/skeleton.dart';

/// Albums tab: two-column grid of user-created memory albums.
class AlbumsPage extends StatefulWidget {
  const AlbumsPage({super.key});

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage> {
  List<AlbumChoice>? _albums;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
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
      final data = await AlbumService.fetchAll();
      if (!mounted) return;
      setState(() {
        _albums = data;
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

  Future<void> _createAlbum() async {
    await showAlbumFormSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Albums'),
        actions: [
          IconButton(
            tooltip: 'New album',
            icon: const Icon(Icons.add),
            onPressed: _createAlbum,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _albums == null) {
      return const SkeletonMemoryGrid();
    }
    if (_error != null && _albums == null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load albums',
        message: '$_error',
        actionLabel: 'Try again',
        onAction: () {
          setState(() => _loading = true);
          _load();
        },
      );
    }
    final albums = _albums;
    if (albums == null || albums.isEmpty) {
      return EmptyState(
        icon: Icons.photo_album_outlined,
        title: 'No albums yet',
        message: 'Group your favorite memories into themed albums.',
        actionLabel: 'Create Album',
        onAction: _createAlbum,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        itemCount: albums.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.82,
        ),
        itemBuilder: (context, index) {
          final album = albums[index];
          return _AlbumCard(
            album: album,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AlbumDetailPage(album: album),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.album, required this.onTap});

  final AlbumChoice album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final countLabel =
        album.entryCount == 1 ? '1 memory' : '${album.entryCount} memories';

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
                  child: ClipRRect(
                    borderRadius: AppRadius.mdAll,
                    child: album.coverUrl == null
                        ? const ColoredBox(
                            color: AppColors.primarySoft,
                            child: Center(
                              child: Icon(
                                Icons.photo_album_outlined,
                                color: AppColors.primary,
                                size: 32,
                              ),
                            ),
                          )
                        : NetworkPhoto(
                            url: album.coverUrl!,
                            storagePath: album.coverPath,
                            thumbnail: true,
                            cacheWidth: 400,
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  album.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  countLabel,
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
