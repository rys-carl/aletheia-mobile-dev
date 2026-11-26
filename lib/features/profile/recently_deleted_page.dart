import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/services/entry_service.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/core/utils/date_format.dart';
import 'package:aletheia_dev/widgets/app_snack_bar.dart';
import 'package:aletheia_dev/widgets/confirm_dialog.dart';
import 'package:aletheia_dev/widgets/empty_state.dart';
import 'package:aletheia_dev/widgets/network_photo.dart';

/// Lists soft-deleted memories so the user can restore or permanently delete them.
class RecentlyDeletedPage extends StatefulWidget {
  const RecentlyDeletedPage({super.key});

  @override
  State<RecentlyDeletedPage> createState() => _RecentlyDeletedPageState();
}

class _RecentlyDeletedPageState extends State<RecentlyDeletedPage> {
  List<Map<String, dynamic>>? _entries;
  Object? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await EntryService.fetchDeleted();
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

  Future<void> _restore(Map<String, dynamic> entry) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await EntryService.restore(entry['id'] as String);
      if (!mounted) return;
      showAppSnackBar(context, 'Memory restored');
      await _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Could not restore: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteForever(Map<String, dynamic> entry) async {
    if (_busy) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Forever?',
      message:
          "Are you sure? This memory and its photos will be permanently deleted and can't be recovered.",
      confirmLabel: 'Delete Forever',
    );
    if (!confirmed || !mounted) return;

    final media = (entry['media'] as List?) ?? const [];
    final paths = [
      for (final m in media)
        if (m is Map && m['storage_path'] is String) m['storage_path'] as String,
    ];

    setState(() => _busy = true);
    try {
      await EntryService.permanentlyDelete(entry['id'] as String, paths);
      if (!mounted) return;
      showAppSnackBar(context, 'Memory permanently deleted');
      await _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Could not delete: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recently Deleted')),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _entries == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _entries == null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load deleted memories',
        message: '$_error',
        actionLabel: 'Try again',
        onAction: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _load();
        },
      );
    }

    final entries = _entries ?? const <Map<String, dynamic>>[];
    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.delete_outline,
        title: 'Trash is empty',
        message: 'Memories you delete will appear here so you can restore them.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: entries.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final thumb = entry['thumb_url'] as String?;
          final thumbPath = entry['thumb_path'] as String?;
          final deletedAt = displayDateTimeOf(entry['deleted_at']);

          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: ClipRRect(
                      borderRadius: AppRadius.smAll,
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
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Deleted $deletedAt',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Restore',
                    onPressed: _busy ? null : () => _restore(entry),
                    icon: const Icon(
                      Icons.restore,
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete forever',
                    onPressed: _busy ? null : () => _deleteForever(entry),
                    icon: const Icon(
                      Icons.delete_forever_outlined,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
