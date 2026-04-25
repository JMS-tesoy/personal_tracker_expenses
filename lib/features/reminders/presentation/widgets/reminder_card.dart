import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/reminder.dart';

class ReminderCard extends StatelessWidget {
  const ReminderCard({super.key, required this.reminder});

  final ReminderModel reminder;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color statusColor = reminder.isOverdue
        ? colorScheme.error
        : reminder.isDueSoon
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.86),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    reminder.billName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ReminderStatusChip(
                  label: _statusLabel(reminder),
                  color: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _ReminderMetric(
                    label: 'Due date',
                    value: _formatDate(reminder.dueDate),
                  ),
                ),
                Expanded(
                  child: _ReminderMetric(
                    label: 'Amount',
                    value: CurrencyFormatter.format(reminder.amount),
                  ),
                ),
              ],
            ),
            if (reminder.assignedPersonName != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                'Assigned to: ${reminder.assignedPersonName!}',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(ReminderModel reminder) {
    if (reminder.isOverdue) return 'OVERDUE';
    if (reminder.isDueSoon) return 'DUE SOON';
    return 'UPCOMING';
  }

  String _formatDate(DateTime date) {
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$m/$d/${date.year}';
  }
}

class _ReminderMetric extends StatelessWidget {
  const _ReminderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _ReminderStatusChip extends StatelessWidget {
  const _ReminderStatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
