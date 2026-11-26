import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aletheia_dev/core/models/entry_photo.dart';
import 'package:aletheia_dev/core/models/place_choice.dart';
import 'package:aletheia_dev/core/utils/date_format.dart';
import 'package:aletheia_dev/core/utils/entry_grouping.dart';
import 'package:aletheia_dev/core/utils/geo.dart';
import 'package:aletheia_dev/widgets/primary_button.dart';

void main() {
  group('date formatting', () {
    test('dateOnly pads month and day', () {
      expect(dateOnly(DateTime(2025, 11, 5)), '2025-11-05');
    });

    test('formatDisplayDate is human friendly', () {
      expect(formatDisplayDate(DateTime(2025, 11, 15)), '15 November 2025');
    });

    test('displayDateOf falls back to the raw text', () {
      expect(displayDateOf('2025-11-15'), '15 November 2025');
      expect(displayDateOf('not a date'), 'not a date');
      expect(displayDateOf(null), '');
    });

    test('formatDisplayTime and formatDisplayDateTime format 12h time', () {
      final afternoon = DateTime(2025, 11, 15, 14, 5);
      expect(formatDisplayTime(afternoon), '2:05 PM');
      expect(formatDisplayDateTime(afternoon), '15 November 2025 · 2:05 PM');
      expect(formatDisplayTime(DateTime(2025, 11, 15, 0, 30)), '12:30 AM');
    });

    test('formatMonthYear formats month and year', () {
      expect(formatMonthYear(DateTime(2025, 11, 15)), 'November 2025');
    });
  });

  group('entry grouping', () {
    test('groups entries by month preserving order', () {
      final entries = [
        {'id': '1', 'happened_at': '2025-11-20T10:00:00'},
        {'id': '2', 'happened_at': '2025-11-05T08:00:00'},
        {'id': '3', 'happened_at': '2025-10-12T18:30:00'},
      ];
      final groups = groupEntriesByMonth(entries);
      expect(groups.length, 2);
      expect(groups[0].label, 'November 2025');
      expect(groups[0].entries.length, 2);
      expect(groups[1].label, 'October 2025');
      expect(groups[1].entries.length, 1);
    });
  });

  group('EntryPhoto', () {
    test('copyWith updates cover and sortOrder', () {
      const photo = EntryPhoto(
        id: 'p1',
        storagePath: 'u/e/1.jpg',
        url: 'https://example.com/1.jpg',
        sortOrder: 0,
        isCover: false,
      );
      final updated = photo.copyWith(isCover: true, sortOrder: 2);
      expect(updated.isCover, isTrue);
      expect(updated.sortOrder, 2);
      expect(updated.storagePath, 'u/e/1.jpg');
    });
  });

  group('place matching', () {
    const home = PlaceChoice(name: 'Home', lat: 14.0, lng: 121.0);

    test('same name within 200 m is the same spot', () {
      const nearby = PlaceChoice(name: ' home ', lat: 14.0005, lng: 121.0);
      expect(isSameSpot(home, nearby), isTrue);
    });

    test('same name but far away is a different spot', () {
      const far = PlaceChoice(name: 'Home', lat: 14.1, lng: 121.0);
      expect(isSameSpot(home, far), isFalse);
    });

    test('different name is a different spot', () {
      const other = PlaceChoice(name: 'Cafe', lat: 14.0, lng: 121.0);
      expect(isSameSpot(home, other), isFalse);
    });
  });

  group('PrimaryButton', () {
    testWidgets('calls onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(label: 'Save', onPressed: () => taps++),
          ),
        ),
      );

      await tester.tap(find.text('Save'));
      expect(taps, 1);
    });

    testWidgets('shows a spinner and ignores taps while loading',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              label: 'Save',
              loading: true,
              onPressed: () => taps++,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsNothing);

      await tester.tap(find.byType(FilledButton));
      expect(taps, 0);
    });
  });
}
