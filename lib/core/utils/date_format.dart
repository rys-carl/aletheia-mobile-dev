const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Formats a date as YYYY-MM-DD.
String dateOnly(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Formats a [DateTime] as a UTC ISO-8601 string for `timestamptz` columns.
String isoTimestamp(DateTime d) => d.toUtc().toIso8601String();

/// Human-friendly date, e.g. "15 November 2025".
String formatDisplayDate(DateTime d) =>
    '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Human-friendly time, e.g. "2:30 PM".
String formatDisplayTime(DateTime d) {
  final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final period = d.hour >= 12 ? 'PM' : 'AM';
  return '$hour12:$minute $period';
}

/// Human-friendly date and time, e.g. "15 November 2025 · 2:30 PM".
String formatDisplayDateTime(DateTime d) =>
    '${formatDisplayDate(d)} · ${formatDisplayTime(d)}';

/// Month and year header, e.g. "November 2025".
String formatMonthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';

/// Parses the raw `happened_at` value from the database in local time, or null.
DateTime? tryParseEntryDate(Object? raw) {
  if (raw is! String) return null;
  final parsed = DateTime.tryParse(raw);
  return parsed?.toLocal();
}

/// Display text for a raw `happened_at` value (date only).
String displayDateOf(Object? raw) {
  final d = tryParseEntryDate(raw);
  return d == null ? '${raw ?? ''}' : formatDisplayDate(d);
}

/// Display text for a raw `happened_at` value (date and time).
String displayDateTimeOf(Object? raw) {
  final d = tryParseEntryDate(raw);
  return d == null ? '${raw ?? ''}' : formatDisplayDateTime(d);
}
