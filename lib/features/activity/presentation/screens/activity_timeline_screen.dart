import 'package:flutter/material.dart';

import '../../data/models/activity_log_model.dart';
import '../../data/repositories/activity_log_repository.dart';
import '../widgets/activity_log_card.dart';

class ActivityTimelineScreen extends StatefulWidget {
  const ActivityTimelineScreen({super.key});

  @override
  State<ActivityTimelineScreen> createState() => _ActivityTimelineScreenState();
}

class _ActivityTimelineScreenState extends State<ActivityTimelineScreen> {
  final ActivityLogRepository _repo = ActivityLogRepository.instance;

  List<ActivityLogModel> _logs = <ActivityLogModel>[];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final List<ActivityLogModel> logs = await _repo.getRecentLogs();
      if (!mounted) return;
      setState(() => _logs = logs);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.error_outline, size: 48, color: colors.error),
                  const SizedBox(height: 12),
                  const Text('Failed to load activity.'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : _logs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.history, size: 56, color: colors.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    'No activity yet.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Actions on bills, loans, and people will appear here.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: _logs.length,
                itemBuilder: (BuildContext context, int index) {
                  return ActivityLogCard(log: _logs[index]);
                },
              ),
            ),
    );
  }
}
