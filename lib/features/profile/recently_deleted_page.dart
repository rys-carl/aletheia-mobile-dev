import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/services/entry_service.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/core/utils/date_format.dart';
import 'package:aletheia_dev/widgets/app_snack_bar.dart';
import 'package:aletheia_dev/widgets/confirm_dialog.dart';
import 'package:aletheia_dev/widgets/empty_state.dart';
import 'package:aletheia_dev/widgets/network_photo.dart';
import 'package:aletheia_dev/widgets/skeleton.dart';

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
  bool _selecting = false;
  final Set<String> _selectedIds = {};

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
        if (data.isEmpty) {
          _selecting = false;
          _selectedIds.clear();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  List<String> _mediaPathsOf(Map<String, dynamic> entry) {
    final media = (entry['media'] as List?) ?? const [];
    return [
      for (final m in media)
        if (m is Map && m['storage_path'] is String)
          m['storage_path'] as String,
    ];
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

    setState(() => _busy = true);
    try {
      await EntryService.permanentlyDelete(
        entry['id'] as String,
        _mediaPathsOf(entry),
      );
      if (!mounted) return;
      showAppSnackBar(context, 'Memory permanently deleted');
      await _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Could not delete: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreSelected() async {
    final entries = _entries ?? const [];
    final targets =
        entries.where((e) => _selectedIds.contains(e['id'])).toList();
    if (targets.isEmpty || _busy) return;

    setState(() => _busy = true);
    try {
      for (final entry in targets) {
        await EntryService.restore(entry['id'] as String);
      }
      if (!mounted) return;
      setState(() {
        _selecting = false;
        _selectedIds.clear();
      });
      showAppSnackBar(
        context,
        'Restored ${targets.length} ${targets.length == 1 ? 'memory' : 'memories'}',
      );
      await _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Could not restore: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteEntries(
    List<Map<String, dynamic>> targets, {
    required String dialogTitle,
    required String dialogMessage,
    required String confirmLabel,
  }) async {
    if (targets.isEmpty || _busy) return;
    final confirmed = await showConfirmDialog(
      context,
      title: dialogTitle,
      message: dialogMessage,
      confirmLabel: confirmLabel,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      for (final entry in targets) {
        await EntryService.permanentlyDelete(
          entry['id'] as String,
          _mediaPathsOf(entry),
        );
      }
      if (!mounted) return;
      setState(() {
        _selecting = false;
        _selectedIds.clear();
      });
      showAppSnackBar(
        context,
        'Permanently deleted ${targets.length} ${targets.length == 1 ? 'memory' : 'memories'}',
      );
      await _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Could not delete: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSelected() async {
    final entries = _entries ?? const [];
    final targets =
        entries.where((e) => _selectedIds.contains(e['id'])).toList();
    await _deleteEntries(
      targets,
      dialogTitle: 'Delete Selected Forever?',
      dialogMessage:
          'Permanently delete ${targets.length} selected ${targets.length == 1 ? 'memory' : 'memories'}? This cannot be undone.',
      confirmLabel: 'Delete Selected',
    );
  }

  Future<void> _deleteAll() async {
    final entries = _entries ?? const [];
    await _deleteEntries(
      entries,
      dialogTitle: 'Delete All Forever?',
      dialogMessage:
          'Permanently delete all ${entries.length} ${entries.length == 1 ? 'memory' : 'memories'} in Recently Deleted? This cannot be undone.',
      confirmLabel: 'Delete All',
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    final entries = _entries ?? const [];
    setState(() {
      if (_selectedIds.length == entries.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(entries.map((e) => e['id'] as String));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries ?? const <Map<String, dynamic>>[];
    final hasEntries = entries.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: _selecting
            ? IconButton(
                tooltip: 'Cancel selection',
                icon: const Icon(Icons.close),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _selecting = false;
                          _selectedIds.clear();
                        }),
              )
            : null,
        title: Text(
          _selecting
              ? '${_selectedIds.length} selected'
              : 'Recently Deleted',
        ),
        actions: [
          if (hasEntries && !_selecting) ...[
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _selecting = true;
                        _selectedIds.clear();
                      }),
              child: const Text('Select'),
            ),
            TextButton(
              onPressed: _busy ? null : _deleteAll,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Delete All'),
            ),
          ] else if (hasEntries && _selecting) ...[
            TextButton(
              onPressed: _busy ? null : _toggleSelectAll,
              child: Text(
                _selectedIds.length == entries.length
                    ? 'Deselect All'
                    : 'Select All',
              ),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _selecting && hasEntries
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _busy || _selectedIds.isEmpty ? null : _restoreSelected,
                        icon: const Icon(Icons.restore),
                        label: const Text('Restore'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            _busy || _selectedIds.isEmpty ? null : _deleteSelected,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: AppColors.onDanger,
                        ),
                        icon: const Icon(Icons.delete_forever_outlined),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading && _entries == null) {
      return const SkeletonList();
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
          final id = entry['id'] as String;
          final selected = _selectedIds.contains(id);
          final thumb = entry['thumb_url'] as String?;
          final thumbPath = entry['thumb_path'] as String?;
          final deletedAt = displayDateTimeOf(entry['deleted_at']);

          return Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              borderRadius: AppRadius.mdAll,
              onTap: _selecting && !_busy ? () => _toggleSelection(id) : null,
              onLongPress: !_selecting && !_busy
                  ? () => setState(() {
                        _selecting = true;
                        _selectedIds.add(id);
                      })
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    if (_selecting) ...[
                      Checkbox(
                        value: selected,
                        onChanged: _busy ? null : (_) => _toggleSelection(id),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
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
                    if (!_selecting) ...[
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
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
