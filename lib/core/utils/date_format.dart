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

/// Formats a date as YYYY-MM-DD, the format the `happened_at` column uses.
String dateOnly(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Human-friendly date, e.g. "15 November 2025".
String formatDisplayDate(DateTime d) =>
    '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Parses the raw `happened_at` value from the database, or null.
DateTime? tryParseEntryDate(Object? raw) =>
    raw is String ? DateTime.tryParse(raw) : null;

/// Display text for a raw `happened_at` value.
String displayDateOf(Object? raw) {
  final d = tryParseEntryDate(raw);
  return d == null ? '${raw ?? ''}' : formatDisplayDate(d);
}
