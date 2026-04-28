import 'package:flutter/material.dart';

import '../../data/models/activity_log_model.dart';
import '../../data/repositories/activity_log_repository.dart';
import '../widgets/activity_log_card.dart';

enum _ActivityFilter {
  all,
  bills,
  loans,
  proofs,
  reminders,
  people,
  money,
}

class ActivityTimelineScreen extends StatefulWidget {
  const ActivityTimelineScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<ActivityTimelineScreen> createState() => _ActivityTimelineScreenState();
}

class _ActivityTimelineScreenState extends State<ActivityTimelineScreen>
    with WidgetsBindingObserver {
  final ActivityLogRepository _repo = ActivityLogRepository.instance;

  List<ActivityLogModel> _logs = <ActivityLogModel>[];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _hasError = false;
  _ActivityFilter _filter = _ActivityFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load(showLoading: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load(showLoading: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    } else {
      setState(() {
        _isRefreshing = true;
        _hasError = false;
      });
    }

    try {
      final List<ActivityLogModel> logs = await _repo.getRecentLogs(limit: 150);

      if (!mounted) return;

      setState(() {
        _logs = logs;
        _hasError = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() => _hasError = true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  List<ActivityLogModel> get _filteredLogs {
    return _logs.where((ActivityLogModel log) {
      return switch (_filter) {
        _ActivityFilter.all => true,
        _ActivityFilter.bills => log.targetType == 'bill',
        _ActivityFilter.loans => log.targetType == 'loan',
        _ActivityFilter.proofs => log.targetType == 'payment_proof',
        _ActivityFilter.reminders => log.targetType == 'reminder',
        _ActivityFilter.people =>
          log.targetType == 'person' || log.targetType == 'people_group',
        _ActivityFilter.money =>
          log.targetType == 'transaction' ||
              log.action == 'marked_paid' ||
              log.action == 'payment_recorded',
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<ActivityLogModel> visibleLogs = _filteredLogs;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
        title: const Text('Activity Timeline'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : () => _load(showLoading: false),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _hasError
                ? _ErrorState(onRetry: () => _load(showLoading: true))
                : RefreshIndicator(
                    onRefresh: () => _load(showLoading: false),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: <Widget>[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _HeaderSummary(
                                  total: _logs.length,
                                  visible: visibleLogs.length,
                                  isRefreshing: _isRefreshing,
                                  colors: colors,
                                ),
                                const SizedBox(height: 12),
                                _FilterChips(
                                  selected: _filter,
                                  onChanged: (activityFilter) {},
                                  onSelected: (activityFilter) {},
                                  onFilterChanged: (_ActivityFilter filter) {
                                    setState(() => _filter = filter);
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                        if (_logs.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyState(
                              message:
                                  'Actions on bills, loans, people, reminders, and proofs will appear here.',
                            ),
                          )
                        else if (visibleLogs.isEmpty)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyState(
                              message:
                                  'No activity found for this filter yet.',
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                            sliver: SliverList.builder(
                              itemCount: visibleLogs.length,
                              itemBuilder: (BuildContext context, int index) {
                                return ActivityLogCard(log: visibleLogs[index]);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _HeaderSummary extends StatelessWidget {
  const _HeaderSummary({
    required this.total,
    required this.visible,
    required this.isRefreshing,
    required this.colors,
  });

  final int total;
  final int visible;
  final bool isRefreshing;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.manage_history, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Audit Trail',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  total == visible
                      ? '$total total activity records'
                      : '$visible shown from $total records',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isRefreshing)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.onFilterChanged,
    required this.onChanged,
    required this.onSelected,
  });

  final _ActivityFilter selected;
  final ValueChanged<_ActivityFilter> onFilterChanged;

  /// Kept to avoid accidental API confusion during paste edits.
  final ValueChanged<ActivityFilter> onChanged;
  final ValueChanged<ActivityFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _chip('All', _ActivityFilter.all),
          _chip('Bills', _ActivityFilter.bills),
          _chip('Loans', _ActivityFilter.loans),
          _chip('Proofs', _ActivityFilter.proofs),
          _chip('Reminders', _ActivityFilter.reminders),
          _chip('People', _ActivityFilter.people),
          _chip('Money', _ActivityFilter.money),
        ],
      ),
    );
  }

  Widget _chip(String label, _ActivityFilter filter) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected == filter,
        onSelected: (_) => onFilterChanged(filter),
      ),
    );
  }
}

/// Dummy public type used only to avoid accidental generic-name conflicts.
/// Do not use elsewhere.
class ActivityFilter {}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.error_outline, size: 48, color: colors.error),
            const SizedBox(height: 12),
            const Text('Failed to load activity.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.history, size: 56, color: colors.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No activity yet.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(color: colors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
