import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/models/place_choice.dart';
import 'package:aletheia_dev/core/services/entry_service.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/core/utils/date_format.dart';
import 'package:aletheia_dev/features/entry/entry_form_page.dart';
import 'package:aletheia_dev/widgets/app_snack_bar.dart';
import 'package:aletheia_dev/widgets/confirm_dialog.dart';
import 'package:aletheia_dev/widgets/network_photo.dart';
import 'package:aletheia_dev/widgets/photo_source_sheet.dart';
import 'package:aletheia_dev/widgets/photo_viewer.dart';
import 'package:aletheia_dev/widgets/primary_button.dart';
import 'package:aletheia_dev/widgets/section_card.dart';

/// Shows one memory: hero photo, photo strip, details, and delete.
class EntryDetailPage extends StatefulWidget {
  const EntryDetailPage({super.key, required this.entry});

  final Map<String, dynamic> entry;

  @override
  State<EntryDetailPage> createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends State<EntryDetailPage> {
  late Map<String, dynamic> _entry;

  List<String> _paths = const [];
  List<String> _urls = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  String get _id => _entry['id'] as String;

  PlaceChoice? get _place {
    final p = _entry['places'];
    return p is Map<String, dynamic> ? PlaceChoice.fromMap(p) : null;
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
        _paths = photos.paths;
        _urls = photos.urls;
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
        builder: (_) => EntryFormPage(entry: _entry, existingUrls: _urls),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _entry = {..._entry, ...updated});
    await _loadPhotos();
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Memory?',
      message:
          "Are you sure you want to delete this memory? Its photos will be deleted too. This can't be undone.",
      confirmLabel: 'Delete Memory',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busy = true);
    try {
      await EntryService.delete(_id, _paths);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _showError('Could not delete: $e');
    }
  }

  Future<void> _addPhotos() async {
    final picked = await pickPhotos(context);
    if (picked.isEmpty || !mounted) return;

    setState(() => _busy = true);
    try {
      await EntryService.addPhotos(_id, picked);
      await _loadPhotos();
    } catch (e) {
      _showError('Could not upload photos: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openViewer(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhotoViewer(urls: _urls, initialIndex: index),
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
          if (_busy) const LinearProgressIndicator(),
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
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: ClipRRect(
        borderRadius: AppRadius.lgAll,
        child: _urls.isEmpty
            ? ColoredBox(
                color: AppColors.primarySoft,
                child: Center(
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Icon(
                          Icons.photo_outlined,
                          size: 40,
                          color: AppColors.primary,
                        ),
                ),
              )
            : GestureDetector(
                onTap: () => _openViewer(0),
                child: NetworkPhoto(url: _urls.first, cacheWidth: 1000),
              ),
      ),
    );
  }

  Widget _buildPhotosCard() {
    final textTheme = Theme.of(context).textTheme;

    Widget content;
    if (_loading) {
      content = const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_error != null) {
      content = Text('Could not load photos:\n$_error');
    } else if (_urls.isEmpty) {
      content = Text(
        'No photos yet.',
        style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      );
    } else {
      content = SizedBox(
        height: 88,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _urls.length,
          separatorBuilder: (context, index) =>
              const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, index) => GestureDetector(
            onTap: () => _openViewer(index),
            child: SizedBox(
              width: 88,
              child: ClipRRect(
                borderRadius: AppRadius.mdAll,
                child: NetworkPhoto(url: _urls[index], cacheWidth: 300),
              ),
            ),
          ),
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
    final place = _place;

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
          _InfoRow(label: 'Date:', value: displayDateOf(_entry['happened_at'])),
          if (place != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(label: 'Location:', value: place.name),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Text(value, style: textTheme.bodyMedium)),
      ],
    );
  }
}
