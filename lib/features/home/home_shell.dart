import 'dart:async';

import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/services/notification_service.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/features/albums/albums_page.dart';
import 'package:aletheia_dev/features/calendar/calendar_page.dart';
import 'package:aletheia_dev/features/entry/entry_form_page.dart';
import 'package:aletheia_dev/features/home/home_page.dart';
import 'package:aletheia_dev/features/map/map_page.dart';
import 'package:aletheia_dev/features/upcoming/moment_ended_prompt_page.dart';
import 'package:aletheia_dev/features/upcoming/upcoming_moment_form_page.dart';
import 'package:aletheia_dev/widgets/app_bottom_bar.dart';

/// The signed-in app frame: Home, Albums, Calendar, and Map tabs plus "+".
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  StreamSubscription<String>? _notifSub;

  @override
  void initState() {
    super.initState();
    _notifSub = NotificationService.onEntryTap.listen(_openMomentPrompt);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pendingId = NotificationService.consumePendingEntryId();
      if (pendingId != null && mounted) {
        _openMomentPrompt(pendingId);
      }
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    super.dispose();
  }

  void _openMomentPrompt(String entryId) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MomentEndedPromptPage(entryId: entryId),
      ),
    );
  }

  Future<void> _addMemory() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.auto_stories_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Log a Memory'),
                subtitle: const Text('Save a moment with photos and notes'),
                onTap: () => Navigator.of(sheetCtx).pop('memory'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.event_available_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('Plan Upcoming Moment'),
                subtitle: const Text('Set a reminder to add photos when it ends'),
                onTap: () => Navigator.of(sheetCtx).pop('upcoming'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => choice == 'upcoming'
            ? const UpcomingMomentFormPage()
            : const EntryFormPage(),
      ),
    );
    // Jump back to the list so the new memory/moment is visible.
    if (created == true && mounted) setState(() => _index = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomePage(),
          AlbumsPage(),
          CalendarPage(),
          MapPage(),
        ],
      ),
      bottomNavigationBar: AppBottomBar(
        currentIndex: _index,
        onSelected: (i) => setState(() => _index = i),
        onAdd: _addMemory,
      ),
    );
  }
}
