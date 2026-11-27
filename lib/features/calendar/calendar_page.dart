import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:aletheia_dev/core/services/entry_service.dart';
import 'package:aletheia_dev/core/state/entries_revision.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/core/utils/date_format.dart';
import 'package:aletheia_dev/features/entry/entry_detail_page.dart';
import 'package:aletheia_dev/widgets/empty_state.dart';
import 'package:aletheia_dev/widgets/network_photo.dart';
import 'package:aletheia_dev/widgets/skeleton.dart';

/// Calendar tab: month view with memory dots per day and a list of memories
/// for the selected day.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  Map<String, List<Map<String, dynamic>>> _byDay = const {};
  Object? _error;
  bool _loading = true;
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    entriesRevision.addListener(_onEntriesChanged);
    _loadMonth(_focusedDay);
  }

  @override
  void dispose() {
    entriesRevision.removeListener(_onEntriesChanged);
    super.dispose();
  }

  void _onEntriesChanged() => _loadMonth(_focusedDay);

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadMonth(DateTime month) async {
    final seq = ++_requestSeq;
    final start = DateTime(month.year, month.month, 1)
        .subtract(const Duration(days: 7));
    final end = DateTime(month.year, month.month + 1, 1)
        .add(const Duration(days: 7));
    try {
      final rows = await EntryService.fetchDateRange(start, end);
      if (!mounted || seq != _requestSeq) return;
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final row in rows) {
        final dt = tryParseEntryDate(row['happened_at']);
        if (dt == null) continue;
        final local = dt.toLocal();
        grouped.putIfAbsent(_dayKey(local), () => []).add(row);
      }
      setState(() {
        _byDay = grouped;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dayEntries = _byDay[_dayKey(_selectedDay)] ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          TextButton(
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _focusedDay = now;
                _selectedDay = now;
              });
              _loadMonth(now);
            },
            child: const Text('Today'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.lgAll,
              boxShadow: AppShadows.card,
            ),
            child: TableCalendar<Map<String, dynamic>>(
              firstDay: DateTime(1970),
              lastDay: DateTime.now().add(const Duration(days: 365 * 5)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
              eventLoader: (day) => _byDay[_dayKey(day)] ?? const [],
              startingDayOfWeek: StartingDayOfWeek.monday,
              availableGestures: AvailableGestures.horizontalSwipe,
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: textTheme.titleMedium!.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
                leftChevronIcon: const Icon(
                  Icons.chevron_left,
                  color: AppColors.primary,
                ),
                rightChevronIcon: const Icon(
                  Icons.chevron_right,
                  color: AppColors.primary,
                ),
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
                selectedDecoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
                markerDecoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
                markerSize: 5,
                outsideDaysVisible: true,
                outsideTextStyle: const TextStyle(color: AppColors.textHint),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _loadMonth(focusedDay);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              formatDisplayDate(_selectedDay),
              style: textTheme.titleSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _loading && _byDay.isEmpty
                ? const SkeletonList(itemCount: 3)
                : _error != null && _byDay.isEmpty
                    ? EmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Could not load calendar',
                        message: '$_error',
                        actionLabel: 'Try again',
                        onAction: () {
                          setState(() => _loading = true);
                          _loadMonth(_focusedDay);
                        },
                      )
                    : dayEntries.isEmpty
                        ? const Center(
                            child: Text(
                              'No memories on this day.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              0,
                              AppSpacing.lg,
                              AppSpacing.xl,
                            ),
                            itemCount: dayEntries.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final entry = dayEntries[index];
                              return _CalendarEntryTile(
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
        ],
      ),
    );
  }
}

class _CalendarEntryTile extends StatelessWidget {
  const _CalendarEntryTile({required this.entry, required this.onTap});

  final Map<String, dynamic> entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final thumbUrl = entry['thumb_url'] as String?;
    final thumbPath = entry['thumb_path'] as String?;
    final feeling = entry['feeling'] as String?;
    final place = entry['places'] as Map<String, dynamic>?;
    final dt = tryParseEntryDate(entry['happened_at']);
    final time = dt == null ? '' : formatDisplayTime(dt);
    final subtitle = [
      if (time.isNotEmpty) time,
      if (place != null) place['name'] as String,
    ].join(' · ');

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.mdAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: AppRadius.smAll,
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: thumbUrl == null
                        ? const ColoredBox(
                            color: AppColors.primarySoft,
                            child: Icon(
                              Icons.auto_stories_outlined,
                              color: AppColors.primary,
                            ),
                          )
                        : NetworkPhoto(
                            url: thumbUrl,
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
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (feeling != null && feeling.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(feeling, style: const TextStyle(fontSize: 18)),
                ],
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.chevron_right, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
