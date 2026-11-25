import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aletheia_dev/core/models/place_choice.dart';
import 'package:aletheia_dev/core/utils/date_format.dart';
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
