import 'package:flutter/foundation.dart';

/// Bumped whenever memories change (created, edited, deleted, photos added).
/// Screens that show memories listen to this and reload themselves, so no
/// screen has to remember to refresh after returning from another one.
final ValueNotifier<int> entriesRevision = ValueNotifier<int>(0);

void notifyEntriesChanged() {
  entriesRevision.value++;
}
