import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:aletheia_dev/core/models/entry_photo.dart';
import 'package:aletheia_dev/core/models/place_choice.dart';
import 'package:aletheia_dev/core/services/entry_service.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/core/utils/date_format.dart';
import 'package:aletheia_dev/features/map/location_picker_page.dart';
import 'package:aletheia_dev/widgets/app_snack_bar.dart';
import 'package:aletheia_dev/widgets/form_section.dart';
import 'package:aletheia_dev/widgets/photo_manager_sheet.dart';
import 'package:aletheia_dev/widgets/photo_source_sheet.dart';
import 'package:aletheia_dev/widgets/photo_strip.dart';
import 'package:aletheia_dev/widgets/picker_field.dart';
import 'package:aletheia_dev/widgets/primary_button.dart';

const _gap = SizedBox(height: AppSpacing.xl);

/// One form for both creating and editing a memory.
///
/// - Create: push with no arguments. Pops `true` after saving.
/// - Edit: pass the [entry] (and its already-saved [existingPhotos]). Pops the
///   updated entry map after saving.
class EntryFormPage extends StatefulWidget {
  const EntryFormPage({
    super.key,
    this.entry,
    this.existingPhotos = const [],
  });

  final Map<String, dynamic>? entry;
  final List<EntryPhoto> existingPhotos;

  bool get isEdit => entry != null;

  @override
  State<EntryFormPage> createState() => _EntryFormPageState();
}

class _EntryFormPageState extends State<EntryFormPage> {
  final _title = TextEditingController();
  final _note = TextEditingController();

  DateTime _date = DateTime.now();
  PlaceChoice? _place;
  bool _placeTouched = false;
  late List<EntryPhoto> _existingPhotos;
  List<XFile> _photos = [];
  String? _createdEntryId;

  bool _saving = false;
  int _uploadDone = 0;
  int _uploadTotal = 0;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _existingPhotos = List<EntryPhoto>.from(widget.existingPhotos);
    final entry = widget.entry;
    if (entry != null) {
      _title.text = entry['title'] as String;
      _note.text = (entry['note'] as String?) ?? '';
      _date = tryParseEntryDate(entry['happened_at']) ?? DateTime.now();
      final p = entry['places'];
      if (p is Map<String, dynamic>) _place = PlaceChoice.fromMap(p);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1970),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = DateTime(
        _date.year,
        _date.month,
        _date.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.of(context).push<PlaceChoice>(
      MaterialPageRoute<PlaceChoice>(
        builder: (_) => LocationPickerPage(initial: _place),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _place = picked;
      _placeTouched = true;
    });
  }

  Future<void> _addPhotos() async {
    final picked = await pickPhotos(context);
    if (picked.isEmpty || !mounted) return;
    setState(() => _photos = [..._photos, ...picked]);
  }

  Future<void> _manageExisting() async {
    final entryId = widget.entry?['id'] as String? ?? _createdEntryId;
    if (entryId == null) return;
    final updated = await showPhotoManagerSheet(
      context,
      entryId: entryId,
      photos: _existingPhotos,
    );
    if (!mounted) return;
    setState(() => _existingPhotos = updated);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Give your memory a title');
      return;
    }
    final note = _note.text.trim();

    setState(() {
      _saving = true;
      _uploadDone = 0;
      _uploadTotal = _photos.length;
    });

    try {
      if (widget.isEdit) {
        final res = await EntryService.update(
          id: widget.entry!['id'] as String,
          title: title,
          note: note.isEmpty ? null : note,
          date: _date,
          place: _place,
          placeTouched: _placeTouched,
          newPhotos: _photos,
          startSortOrder: _existingPhotos.length,
          onUploadProgress: _onUploadProgress,
        );
        if (!mounted) return;
        if (res.uploadResult.hasFailures) {
          setState(() {
            _saving = false;
            _uploadTotal = 0;
            _photos = res.uploadResult.failedFiles;
          });
          showAppSnackBar(
            context,
            'Details saved, but ${res.uploadResult.failedFiles.length} photo(s) failed.',
            actionLabel: 'Retry',
            onAction: _retryPendingUploads,
          );
          return;
        }
        Navigator.of(context).pop(res.entry);
      } else if (_createdEntryId != null) {
        // Entry was already created on an earlier attempt; only retry uploads.
        final res = await EntryService.addPhotos(
          _createdEntryId!,
          _photos,
          startSortOrder: _existingPhotos.length,
          onUploadProgress: _onUploadProgress,
        );
        if (!mounted) return;
        if (res.hasFailures) {
          setState(() {
            _saving = false;
            _uploadTotal = 0;
            _photos = res.failedFiles;
          });
          showAppSnackBar(
            context,
            '${res.failedFiles.length} photo(s) still failed to upload.',
            actionLabel: 'Retry',
            onAction: _retryPendingUploads,
          );
          return;
        }
        Navigator.of(context).pop(true);
      } else {
        final res = await EntryService.create(
          title: title,
          note: note.isEmpty ? null : note,
          date: _date,
          place: _place,
          photos: _photos,
          onUploadProgress: _onUploadProgress,
        );
        if (!mounted) return;
        if (res.uploadResult.hasFailures) {
          setState(() {
            _createdEntryId = res.id;
            _saving = false;
            _uploadTotal = 0;
            _photos = res.uploadResult.failedFiles;
          });
          showAppSnackBar(
            context,
            'Memory saved, but ${res.uploadResult.failedFiles.length} photo(s) failed.',
            actionLabel: 'Retry',
            onAction: _retryPendingUploads,
          );
          return;
        }
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _uploadTotal = 0;
      });
      showAppSnackBar(context, 'Could not save: $e');
    }
  }

  void _onUploadProgress(int done, int total) {
    if (!mounted) return;
    setState(() {
      _uploadDone = done;
      _uploadTotal = total;
    });
  }

  Future<void> _retryPendingUploads() async {
    if (_saving || _photos.isEmpty) return;
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEdit ? 'Update Details' : 'Create Memory'),
        ),
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            FormSection(
              label: 'Title',
              child: TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_titleError != null) setState(() => _titleError = null);
                },
                decoration: InputDecoration(
                  hintText: 'Give this memory a title',
                  errorText: _titleError,
                ),
              ),
            ),
            _gap,
            FormSection(
              label: 'Description',
              child: TextField(
                controller: _note,
                minLines: 4,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'What made this moment special?',
                ),
              ),
            ),
            _gap,
            FormSection(
              label: 'Date & Time',
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: PickerField(
                      icon: Icons.calendar_today_outlined,
                      text: formatDisplayDate(_date),
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: PickerField(
                      icon: Icons.schedule_outlined,
                      text: formatDisplayTime(_date),
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
            ),
            _gap,
            FormSection(
              label: 'Location',
              child: PickerField(
                icon: Icons.place_outlined,
                text: _place?.name,
                placeholder: 'Add a location',
                onTap: _pickLocation,
                onClear: _place == null
                    ? null
                    : () => setState(() {
                          _place = null;
                          _placeTouched = true;
                        }),
              ),
            ),
            _gap,
            FormSection(
              label: 'Photos',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PhotoStrip(
                    onAdd: _addPhotos,
                    existingPhotos: _existingPhotos,
                    onManageExisting:
                        _existingPhotos.isEmpty ? null : _manageExisting,
                    pending: _photos,
                    onRemovePending: (i) => setState(() {
                      _photos = [..._photos]..removeAt(i);
                    }),
                  ),
                  if (_existingPhotos.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        'Tap a saved photo to reorder, set cover, or delete.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ),
                ],
              ),
            ),
            if (_saving && _uploadTotal > 0) ...[
              const SizedBox(height: AppSpacing.lg),
              LinearProgressIndicator(value: _uploadDone / _uploadTotal),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Uploading photo $_uploadDone of $_uploadTotal...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: _createdEntryId != null
                  ? 'Retry Photo Upload'
                  : (widget.isEdit ? 'Update Details' : 'Save Memory'),
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
