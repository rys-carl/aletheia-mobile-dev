import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:aletheia_dev/core/models/place_choice.dart';
import 'package:aletheia_dev/core/services/entry_service.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/core/utils/date_format.dart';
import 'package:aletheia_dev/features/map/location_picker_page.dart';
import 'package:aletheia_dev/widgets/app_snack_bar.dart';
import 'package:aletheia_dev/widgets/form_section.dart';
import 'package:aletheia_dev/widgets/photo_source_sheet.dart';
import 'package:aletheia_dev/widgets/photo_strip.dart';
import 'package:aletheia_dev/widgets/picker_field.dart';
import 'package:aletheia_dev/widgets/primary_button.dart';

const _gap = SizedBox(height: AppSpacing.xl);

/// One form for both creating and editing a memory.
///
/// - Create: push with no arguments. Pops `true` after saving.
/// - Edit: pass the [entry] (and its already-saved photo links as
///   [existingUrls]). Pops the updated entry map after saving.
class EntryFormPage extends StatefulWidget {
  const EntryFormPage({
    super.key,
    this.entry,
    this.existingUrls = const [],
  });

  final Map<String, dynamic>? entry;
  final List<String> existingUrls;

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
  List<XFile> _photos = [];

  bool _saving = false;
  String? _titleError;

  @override
  void initState() {
    super.initState();
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
    setState(() => _date = picked);
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

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Give your memory a title');
      return;
    }
    final note = _note.text.trim();

    setState(() => _saving = true);
    try {
      if (widget.isEdit) {
        final updated = await EntryService.update(
          id: widget.entry!['id'] as String,
          title: title,
          note: note.isEmpty ? null : note,
          date: _date,
          place: _place,
          placeTouched: _placeTouched,
          newPhotos: _photos,
        );
        if (!mounted) return;
        Navigator.of(context).pop(updated);
      } else {
        await EntryService.create(
          title: title,
          note: note.isEmpty ? null : note,
          date: _date,
          place: _place,
          photos: _photos,
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, 'Could not save: $e');
    }
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
              label: 'Date',
              child: PickerField(
                icon: Icons.calendar_today_outlined,
                text: formatDisplayDate(_date),
                onTap: _pickDate,
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
              child: PhotoStrip(
                onAdd: _addPhotos,
                existingUrls: widget.existingUrls,
                pending: _photos,
                onRemovePending: (i) => setState(() {
                  _photos = [..._photos]..removeAt(i);
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: widget.isEdit ? 'Update Details' : 'Save Memory',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
