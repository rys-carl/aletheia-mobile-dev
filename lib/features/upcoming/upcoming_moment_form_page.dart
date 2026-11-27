import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/models/album_choice.dart';
import 'package:aletheia_dev/core/models/place_choice.dart';
import 'package:aletheia_dev/core/services/album_service.dart';
import 'package:aletheia_dev/core/services/entry_service.dart';
import 'package:aletheia_dev/core/services/notification_service.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/core/utils/date_format.dart';
import 'package:aletheia_dev/features/albums/album_form_sheet.dart';
import 'package:aletheia_dev/features/map/location_picker_page.dart';
import 'package:aletheia_dev/widgets/app_snack_bar.dart';
import 'package:aletheia_dev/widgets/form_section.dart';
import 'package:aletheia_dev/widgets/picker_field.dart';
import 'package:aletheia_dev/widgets/primary_button.dart';

const _gap = SizedBox(height: AppSpacing.xl);

/// Form to plan an upcoming moment (`type: 'upcoming'`) and schedule a local
/// notification for when it ends.
class UpcomingMomentFormPage extends StatefulWidget {
  const UpcomingMomentFormPage({super.key});

  @override
  State<UpcomingMomentFormPage> createState() => _UpcomingMomentFormPageState();
}

class _UpcomingMomentFormPageState extends State<UpcomingMomentFormPage> {
  final _title = TextEditingController();
  final _note = TextEditingController();

  late DateTime _startsAt;
  late DateTime _endsAt;
  PlaceChoice? _place;
  AlbumChoice? _album;

  bool _saving = false;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startsAt = DateTime(now.year, now.month, now.day, now.hour + 1);
    _endsAt = _startsAt.add(const Duration(hours: 2));
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final current = isStart ? _startsAt : _endsAt;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (pickedTime == null || !mounted) return;

    final next = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      if (isStart) {
        _startsAt = next;
        if (!_endsAt.isAfter(_startsAt)) {
          _endsAt = _startsAt.add(const Duration(hours: 1));
        }
      } else {
        _endsAt = next;
      }
    });
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.of(context).push<PlaceChoice>(
      MaterialPageRoute<PlaceChoice>(
        builder: (_) => LocationPickerPage(initial: _place),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _place = picked);
  }

  Future<void> _pickAlbum() async {
    final picked = await showModalBottomSheet<AlbumChoice>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetCtx) => FutureBuilder<List<AlbumChoice>>(
        future: AlbumService.fetchChoices(),
        builder: (context, snapshot) {
          final albums = snapshot.data;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Choose Album',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('New Album'),
                          onPressed: () async {
                            final created = await showAlbumFormSheet(context);
                            if (created != null && sheetCtx.mounted) {
                              Navigator.of(sheetCtx).pop(created);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Center(child: LinearProgressIndicator()),
                    )
                  else if (albums == null || albums.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        'No albums yet. Tap "New Album" to create one.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: albums.length,
                        itemBuilder: (_, i) {
                          final a = albums[i];
                          return ListTile(
                            leading: const Icon(
                              Icons.photo_album_outlined,
                              color: AppColors.primary,
                            ),
                            title: Text(a.title),
                            onTap: () => Navigator.of(sheetCtx).pop(a),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _album = picked);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Give your upcoming moment a title');
      return;
    }
    if (!_endsAt.isAfter(_startsAt)) {
      showAppSnackBar(context, 'End time must be after start time.');
      return;
    }

    final note = _note.text.trim();
    setState(() => _saving = true);
    try {
      final id = await EntryService.createUpcoming(
        title: title,
        note: note.isEmpty ? null : note,
        startsAt: _startsAt,
        endsAt: _endsAt,
        place: _place,
        albumId: _album?.id,
      );
      await NotificationService.scheduleMomentStarted(
        entryId: id,
        title: title,
        when: _startsAt,
      );
      await NotificationService.scheduleMomentEnded(
        entryId: id,
        title: title,
        when: _endsAt,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, 'Could not save upcoming moment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Plan Upcoming Moment')),
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
                  hintText: 'e.g. Weekend Beach Trip',
                  errorText: _titleError,
                ),
              ),
            ),
            _gap,
            FormSection(
              label: 'Starts',
              child: PickerField(
                icon: Icons.event_outlined,
                text: formatDisplayDateTime(_startsAt),
                onTap: () => _pickDateTime(isStart: true),
              ),
            ),
            _gap,
            FormSection(
              label: 'Ends (reminder time)',
              child: PickerField(
                icon: Icons.notifications_active_outlined,
                text: formatDisplayDateTime(_endsAt),
                onTap: () => _pickDateTime(isStart: false),
              ),
            ),
            _gap,
            FormSection(
              label: 'Location (optional)',
              child: PickerField(
                icon: Icons.place_outlined,
                text: _place?.name,
                placeholder: 'Add a location',
                onTap: _pickLocation,
                onClear:
                    _place == null ? null : () => setState(() => _place = null),
              ),
            ),
            _gap,
            FormSection(
              label: 'Album (optional)',
              child: PickerField(
                icon: Icons.photo_album_outlined,
                text: _album?.title,
                placeholder: 'Add to an album',
                onTap: _pickAlbum,
                onClear:
                    _album == null ? null : () => setState(() => _album = null),
              ),
            ),
            _gap,
            FormSection(
              label: 'Notes (optional)',
              child: TextField(
                controller: _note,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Anything to remember for this event?',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: 'Save & Schedule Reminder',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
