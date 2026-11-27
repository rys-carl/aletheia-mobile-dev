import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/models/album_choice.dart';
import 'package:aletheia_dev/core/services/album_service.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/widgets/app_snack_bar.dart';
import 'package:aletheia_dev/widgets/form_section.dart';
import 'package:aletheia_dev/widgets/primary_button.dart';

/// Opens a bottom sheet to create a new album or edit an existing [album].
/// Returns the saved [AlbumChoice], or `null` if cancelled.
Future<AlbumChoice?> showAlbumFormSheet(
  BuildContext context, {
  AlbumChoice? album,
}) {
  return showModalBottomSheet<AlbumChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => _AlbumFormSheet(album: album),
  );
}

class _AlbumFormSheet extends StatefulWidget {
  const _AlbumFormSheet({this.album});

  final AlbumChoice? album;

  @override
  State<_AlbumFormSheet> createState() => _AlbumFormSheetState();
}

class _AlbumFormSheetState extends State<_AlbumFormSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.album?.title ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.album?.description ?? '');

  bool _saving = false;
  String? _titleError;

  bool get _isEdit => widget.album != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Give your album a name');
      return;
    }
    final description = _description.text.trim();
    setState(() => _saving = true);
    try {
      final saved = _isEdit
          ? await AlbumService.update(
              id: widget.album!.id,
              title: title,
              description: description.isEmpty ? null : description,
            )
          : await AlbumService.create(
              title: title,
              description: description.isEmpty ? null : description,
            );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, 'Could not save album: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEdit ? 'Edit Album' : 'New Album',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FormSection(
            label: 'Name',
            child: TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_titleError != null) setState(() => _titleError = null);
              },
              decoration: InputDecoration(
                hintText: 'e.g. Summer Trip 2026',
                errorText: _titleError,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FormSection(
            label: 'Description (optional)',
            child: TextField(
              controller: _description,
              minLines: 2,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'What is this album about?',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: _isEdit ? 'Save Changes' : 'Create Album',
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
