import 'dart:async';

import 'package:flutter/material.dart';

import 'package:aletheia_dev/core/models/place_choice.dart';
import 'package:aletheia_dev/core/services/entry_service.dart';
import 'package:aletheia_dev/core/services/place_service.dart';
import 'package:aletheia_dev/core/services/supabase_client.dart';
import 'package:aletheia_dev/core/state/entries_revision.dart';
import 'package:aletheia_dev/core/theme/app_colors.dart';
import 'package:aletheia_dev/core/theme/app_dimens.dart';
import 'package:aletheia_dev/core/utils/date_format.dart';
import 'package:aletheia_dev/core/utils/entry_grouping.dart';
import 'package:aletheia_dev/features/entry/entry_detail_page.dart';
import 'package:aletheia_dev/features/profile/profile_page.dart';
import 'package:aletheia_dev/widgets/app_snack_bar.dart';
import 'package:aletheia_dev/widgets/empty_state.dart';
import 'package:aletheia_dev/widgets/memory_card.dart';

/// Home tab: greeting, search & filters, month-grouped two-column grid of
/// memories with pagination, newest first.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  List<Map<String, dynamic>>? _entries;
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  int _requestSeq = 0;

  String _query = '';
  DateTimeRange? _dateRange;
  PlaceChoice? _selectedPlace;

  bool get _hasActiveFilters =>
      _query.trim().isNotEmpty ||
      _dateRange != null ||
      _selectedPlace != null;

  @override
  void initState() {
    super.initState();
    entriesRevision.addListener(_onEntriesChanged);
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    entriesRevision.removeListener(_onEntriesChanged);
    super.dispose();
  }

  void _onEntriesChanged() {
    _loadFirstPage();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadFirstPage() async {
    final seq = ++_requestSeq;
    try {
      final data = await EntryService.fetchPage(
        page: 0,
        query: _query,
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
        placeId: _selectedPlace?.id,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _entries = data;
        _page = 0;
        _hasMore = data.length >= EntryService.defaultPageSize;
        _error = null;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      final hadData = _entries != null;
      setState(() {
        _error = e;
        _loading = false;
        _loadingMore = false;
      });
      if (hadData) showAppSnackBar(context, 'Could not refresh: $e');
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final seq = _requestSeq;
    final nextPage = _page + 1;
    setState(() => _loadingMore = true);
    try {
      final more = await EntryService.fetchPage(
        page: nextPage,
        query: _query,
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
        placeId: _selectedPlace?.id,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _entries = [...?_entries, ...more];
        _page = nextPage;
        _hasMore = more.length >= EntryService.defaultPageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() => _loadingMore = false);
      showAppSnackBar(context, 'Could not load more: $e');
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _query = value;
        _loading = _entries == null;
      });
      _loadFirstPage();
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _dateRange,
    );
    if (picked == null || !mounted) return;
    setState(() => _dateRange = picked);
    _loadFirstPage();
  }

  Future<void> _pickPlace() async {
    try {
      final places = await PlaceService.fetchAll();
      if (!mounted) return;
      if (places.isEmpty) {
        showAppSnackBar(context, 'No saved places yet.');
        return;
      }

      final chosen = await showModalBottomSheet<PlaceChoice>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  'Filter by Place',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in places)
                      ListTile(
                        leading: const Icon(
                          Icons.place_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(p.name),
                        trailing: _selectedPlace?.id == p.id
                            ? const Icon(Icons.check, color: AppColors.primary)
                            : null,
                        onTap: () => Navigator.pop(sheetContext, p),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      if (chosen == null || !mounted) return;
      setState(() => _selectedPlace = chosen);
      _loadFirstPage();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'Could not load places: $e');
    }
  }

  void _clearFilters() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _query = '';
      _dateRange = null;
      _selectedPlace = null;
    });
    _loadFirstPage();
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _loadFirstPage();
  }

  Future<void> _openEntry(Map<String, dynamic> entry) async {
    final deletedId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => EntryDetailPage(entry: entry)),
    );
    if (deletedId == null || !mounted) return;
    showAppSnackBar(
      context,
      'Memory moved to Recently Deleted',
      actionLabel: 'Undo',
      onAction: () async {
        try {
          await EntryService.restore(deletedId);
        } catch (e) {
          if (mounted) showAppSnackBar(context, 'Could not restore: $e');
        }
      },
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ProfilePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(onProfile: _openProfile),
            _SearchAndFilters(
              controller: _searchController,
              dateRange: _dateRange,
              selectedPlace: _selectedPlace,
              hasActiveFilters: _hasActiveFilters,
              onSearchChanged: _onSearchChanged,
              onPickDateRange: _pickDateRange,
              onClearDateRange: () {
                setState(() => _dateRange = null);
                _loadFirstPage();
              },
              onPickPlace: _pickPlace,
              onClearPlace: () {
                setState(() => _selectedPlace = null);
                _loadFirstPage();
              },
              onClearAll: _clearFilters,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _entries == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _entries == null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load memories',
        message: '$_error',
        actionLabel: 'Try again',
        onAction: _retry,
      );
    }

    final entries = _entries ?? const <Map<String, dynamic>>[];
    if (entries.isEmpty) {
      if (_hasActiveFilters) {
        return EmptyState(
          icon: Icons.search_off_outlined,
          title: 'No matching memories',
          message: 'Try a different search term or clear your filters.',
          actionLabel: 'Clear filters',
          onAction: _clearFilters,
        );
      }
      return const EmptyState(
        icon: Icons.auto_stories_outlined,
        title: 'No memories yet',
        message: 'Tap the + button to capture your first one.',
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final groups = groupEntriesByMonth(entries);

    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _hasActiveFilters ? 'Filtered Memories' : 'Recent Memories',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${entries.length}${_hasMore ? '+' : ''} ${entries.length == 1 && !_hasMore ? 'memory' : 'memories'}',
                    style: textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          for (final group in groups) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  group.label,
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.78,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = group.entries[index];
                    return MemoryCard(
                      entry: entry,
                      onTap: () => _openEntry(entry),
                    );
                  },
                  childCount: group.entries.length,
                ),
              ),
            ),
          ],
          if (_loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      ),
    );
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.dateRange,
    required this.selectedPlace,
    required this.hasActiveFilters,
    required this.onSearchChanged,
    required this.onPickDateRange,
    required this.onClearDateRange,
    required this.onPickPlace,
    required this.onClearPlace,
    required this.onClearAll,
  });

  final TextEditingController controller;
  final DateTimeRange? dateRange;
  final PlaceChoice? selectedPlace;
  final bool hasActiveFilters;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onPickDateRange;
  final VoidCallback onClearDateRange;
  final VoidCallback onPickPlace;
  final VoidCallback onClearPlace;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final dateLabel = dateRange == null
        ? 'Date'
        : '${formatDisplayDate(dateRange!.start)} – ${formatDisplayDate(dateRange!.end)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => TextField(
              controller: controller,
              onChanged: onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search titles and notes...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 10,
                ),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          controller.clear();
                          onSearchChanged('');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                InputChip(
                  avatar: const Icon(Icons.date_range_outlined, size: 16),
                  label: Text(dateLabel),
                  selected: dateRange != null,
                  onPressed: onPickDateRange,
                  onDeleted: dateRange != null ? onClearDateRange : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                InputChip(
                  avatar: const Icon(Icons.place_outlined, size: 16),
                  label: Text(selectedPlace?.name ?? 'Place'),
                  selected: selectedPlace != null,
                  onPressed: onPickPlace,
                  onDeleted: selectedPlace != null ? onClearPlace : null,
                ),
                if (hasActiveFilters) ...[
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: onClearAll,
                    child: const Text('Clear'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onProfile});

  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final email = supabase.auth.currentUser?.email ?? '';
    final name = email.isEmpty ? 'there' : email.split('@').first;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: onProfile,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary,
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Your memories, all in one place',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
