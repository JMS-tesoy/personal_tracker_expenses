import 'package:flutter/material.dart';

import '../../../../features/activity/data/repositories/activity_log_repository.dart';
import '../../data/models/reminder_model.dart';
import '../../data/repositories/reminder_repository.dart';
import '../widgets/reminder_card.dart';
import '../widgets/reminder_form_sheet.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<ReminderModel> _active = <ReminderModel>[];
  List<ReminderModel> _history = <ReminderModel>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);

    final List<ReminderModel> active = await ReminderRepository.instance
        .getActiveReminders();
    final List<ReminderModel> history = await ReminderRepository.instance
        .getHistoryReminders();

    if (!mounted) return;
    setState(() {
      _active = active;
      _history = history;
      _isLoading = false;
    });
  }

  Future<void> _addReminder() async {
    final ReminderModel? result = await showReminderFormSheet(context);
    if (result != null) {
      await ActivityLogRepository.instance.createLog(
        targetType: result.targetType,
        action: 'reminder_created',
        title: 'Reminder created',
        targetId: result.targetId,
        personId: result.personId,
        description: '${result.title} was scheduled.',
        metadata: <String, dynamic>{
          'reminder_title': result.title,
          'remind_at': result.remindAt.toIso8601String(),
        },
      );
      _load();
    }
  }

  Future<void> _editReminder(ReminderModel r) async {
    final ReminderModel? result = await showReminderFormSheet(
      context,
      existingReminder: r,
    );
    if (result != null) _load();
  }

  Future<void> _markDone(ReminderModel r) async {
    await ReminderRepository.instance.markReminderCompleted(r);
    await ActivityLogRepository.instance.createLog(
      targetType: r.targetType,
      action: 'reminder_completed',
      title: 'Reminder completed',
      targetId: r.targetId,
      personId: r.personId,
      description: '${r.title} was marked as done.',
      metadata: <String, dynamic>{'reminder_title': r.title},
    );
    _load();
  }

  Future<void> _cancelReminder(ReminderModel r) async {
    await ReminderRepository.instance.cancelReminder(r);
    await ActivityLogRepository.instance.createLog(
      targetType: r.targetType,
      action: 'reminder_cancelled',
      title: 'Reminder cancelled',
      targetId: r.targetId,
      personId: r.personId,
      description: '${r.title} was cancelled.',
      metadata: <String, dynamic>{'reminder_title': r.title},
    );
    _load();
  }

  Future<void> _deleteReminder(ReminderModel r) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: const Text('This reminder will be permanently deleted.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ReminderRepository.instance.deleteReminder(r);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(text: 'Upcoming'),
            Tab(text: 'History'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addReminder,
        tooltip: 'Add reminder',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: <Widget>[
                _ReminderList(
                  reminders: _active,
                  emptyMessage: 'No upcoming reminders.\nTap + to add one.',
                  onMarkDone: _markDone,
                  onEdit: _editReminder,
                  onCancel: _cancelReminder,
                  onDelete: _deleteReminder,
                ),
                _ReminderList(
                  reminders: _history,
                  emptyMessage: 'No reminder history yet.',
                  onDelete: _deleteReminder,
                ),
              ],
            ),
    );
  }
}

// ── Private list widget ───────────────────────────────────────────────────────

class _ReminderList extends StatelessWidget {
  const _ReminderList({
    required this.reminders,
    required this.emptyMessage,
    this.onMarkDone,
    this.onEdit,
    this.onCancel,
    this.onDelete,
  });

  final List<ReminderModel> reminders;
  final String emptyMessage;
  final void Function(ReminderModel)? onMarkDone;
  final void Function(ReminderModel)? onEdit;
  final void Function(ReminderModel)? onCancel;
  final void Function(ReminderModel)? onDelete;

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: reminders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (BuildContext ctx, int i) {
          final ReminderModel r = reminders[i];
          return ReminderCard(
            reminder: r,
            onMarkDone: onMarkDone != null ? () => onMarkDone!(r) : null,
            onEdit: onEdit != null ? () => onEdit!(r) : null,
            onCancel: onCancel != null ? () => onCancel!(r) : null,
            onDelete: onDelete != null ? () => onDelete!(r) : null,
          );
        },
      ),
    );
  }
}
