import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/current_user.dart';
import '../../../bills/domain/bill.dart';
import '../../domain/reminder.dart';
import '../widgets/reminder_card.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<ReminderModel> _overdue = <ReminderModel>[];
  List<ReminderModel> _dueSoon = <ReminderModel>[];
  List<ReminderModel> _upcoming = <ReminderModel>[];

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    setState(() => _isLoading = true);

    try {
      final String userId = requireCurrentUserId();
      final List<dynamic> people = await _supabase
          .from('people')
          .select('id, name')
          .eq('user_id', userId);
      final Map<String, String> peopleNames = <String, String>{
        for (final dynamic p in people)
          (p as Map<String, dynamic>)['id'].toString(): p['name'].toString(),
      };

      final List<dynamic> rows = await _supabase
          .from('bills')
          .select()
          .eq('user_id', userId)
          .order('due_day', ascending: true);
      final List<ReminderModel> reminders =
          rows
              .map((dynamic row) {
                final Map<String, dynamic> billRow = Map<String, dynamic>.from(
                  row as Map<String, dynamic>,
                );
                billRow['assigned_person_name'] =
                    peopleNames[billRow['assigned_person_id']?.toString()];
                return BillModel.fromMap(billRow);
              })
              .where((BillModel bill) => !bill.isPaid)
              .map(ReminderModel.fromBill)
              .toList()
            ..sort((ReminderModel a, ReminderModel b) {
              return a.dueDate.compareTo(b.dueDate);
            });

      if (!mounted) return;
      setState(() {
        _overdue = reminders
            .where((ReminderModel reminder) => reminder.isOverdue)
            .toList();
        _dueSoon = reminders
            .where((ReminderModel reminder) => reminder.isDueSoon)
            .toList();
        _upcoming = reminders
            .where(
              (ReminderModel reminder) =>
                  !reminder.isOverdue && !reminder.isDueSoon,
            )
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load reminders.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool hasReminders =
        _overdue.isNotEmpty || _dueSoon.isNotEmpty || _upcoming.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadReminders,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: <Widget>[
                    Text(
                      'Reminders',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Upcoming and overdue bill reminders',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!hasReminders)
                      _EmptyReminders(colorScheme: colorScheme)
                    else ...<Widget>[
                      _ReminderSection(
                        title: 'Overdue',
                        reminders: _overdue,
                        titleColor: colorScheme.error,
                      ),
                      _ReminderSection(
                        title: 'Due Soon',
                        reminders: _dueSoon,
                        titleColor: colorScheme.primary,
                      ),
                      _ReminderSection(
                        title: 'Upcoming',
                        reminders: _upcoming,
                        titleColor: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _ReminderSection extends StatelessWidget {
  const _ReminderSection({
    required this.title,
    required this.reminders,
    required this.titleColor,
  });

  final String title;
  final List<ReminderModel> reminders;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 4),
          child: Row(
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: titleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${reminders.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...reminders.map(
          (ReminderModel reminder) => ReminderCard(reminder: reminder),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _EmptyReminders extends StatelessWidget {
  const _EmptyReminders({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.notifications_none_outlined,
            size: 56,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No bill reminders',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            "You're all caught up!",
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
