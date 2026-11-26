import 'package:aletheia_dev/core/utils/date_format.dart';

/// A month section in the Home grid (e.g. "November 2025").
class MonthGroup {
  const MonthGroup({required this.label, required this.entries});

  final String label;
  final List<Map<String, dynamic>> entries;
}

/// Groups already-sorted [entries] by local year and month, preserving order.
List<MonthGroup> groupEntriesByMonth(List<Map<String, dynamic>> entries) {
  final groups = <MonthGroup>[];
  String? currentKey;
  var currentItems = <Map<String, dynamic>>[];
  var currentLabel = '';

  for (final entry in entries) {
    final date = tryParseEntryDate(entry['happened_at']);
    final key = date == null ? 'unknown' : '${date.year}-${date.month}';
    final label = date == null ? 'Other' : formatMonthYear(date);

    if (key != currentKey) {
      if (currentItems.isNotEmpty) {
        groups.add(MonthGroup(label: currentLabel, entries: currentItems));
      }
      currentKey = key;
      currentLabel = label;
      currentItems = [entry];
    } else {
      currentItems.add(entry);
    }
  }

  if (currentItems.isNotEmpty) {
    groups.add(MonthGroup(label: currentLabel, entries: currentItems));
  }
  return groups;
}
