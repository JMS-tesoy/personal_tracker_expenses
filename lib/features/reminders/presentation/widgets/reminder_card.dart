// lib/features/reminders/presentation/widgets/reminder_card.dart

import 'package:flutter/material.dart';

import '../../data/models/reminder_model.dart';

class ReminderCard extends StatelessWidget {
  const ReminderCard({
    super.key,
    required this.reminder,
    this.onMarkDone,
    this.onCancel,
    this.onDelete,
    this.onEdit,
  });

  final ReminderModel reminder;
  final VoidCallback? onMarkDone;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.70),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Icon
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _iconBgColor(colorScheme),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _targetIcon(),
                color: _iconColor(colorScheme),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Title + status chip
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          reminder.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      _StatusChip(status: reminder.status),
                    ],
                  ),
                  if (reminder.message != null &&
                      reminder.message!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      reminder.message!,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Meta row
                  Wrap(
                    spacing: 10,
                    children: <Widget>[
                      _MetaChip(
                        icon: Icons.label_outline,
                        label: reminder.displayTargetType,
                        colorScheme: colorScheme,
                      ),
                      _MetaChip(
                        icon: Icons.notifications_outlined,
                        label: _formatDateTime(reminder.remindAt),
                        colorScheme: colorScheme,
                      ),
                      if (reminder.dueAt != null)
                        _MetaChip(
                          icon: Icons.event_outlined,
                          label: 'Due ${_formatDate(reminder.dueAt!)}',
                          colorScheme: colorScheme,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions menu
            if (reminder.isActive)
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                onSelected: (String val) {
                  if (val == 'done') onMarkDone?.call();
                  if (val == 'edit') onEdit?.call();
                  if (val == 'cancel') onCancel?.call();
                  if (val == 'delete') onDelete?.call();
                },
                itemBuilder: (_) => <PopupMenuEntry<String>>[
                  if (onMarkDone != null)
                    const PopupMenuItem<String>(
                      value: 'done',
                      child: Text('Mark as done'),
                    ),
                  if (onEdit != null)
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                  if (onCancel != null)
                    const PopupMenuItem<String>(
                      value: 'cancel',
                      child: Text('Cancel reminder'),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                ],
              )
            else
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  color: colorScheme.error,
                  size: 20,
                ),
                tooltip: 'Delete',
              ),
          ],
        ),
      ),
    );
  }

  IconData _targetIcon() {
    return switch (reminder.targetType) {
      'bill' => Icons.receipt_long_outlined,
      'loan' => Icons.account_balance_outlined,
      'person' => Icons.person_outline,
      'payment' => Icons.payments_outlined,
      _ => Icons.notifications_outlined,
    };
  }

  Color _iconBgColor(ColorScheme cs) {
    return switch (reminder.targetType) {
      'bill' => cs.errorContainer.withValues(alpha: 0.60),
      'loan' => cs.primaryContainer.withValues(alpha: 0.60),
      'person' => cs.tertiaryContainer.withValues(alpha: 0.60),
      _ => cs.secondaryContainer.withValues(alpha: 0.60),
    };
  }

  Color _iconColor(ColorScheme cs) {
    return switch (reminder.targetType) {
      'bill' => cs.onErrorContainer,
      'loan' => cs.onPrimaryContainer,
      'person' => cs.onTertiaryContainer,
      _ => cs.onSecondaryContainer,
    };
  }

  String _formatDateTime(DateTime dt) {
    final String mo = dt.month.toString().padLeft(2, '0');
    final String da = dt.day.toString().padLeft(2, '0');
    final int h = dt.hour > 12
        ? dt.hour - 12
        : dt.hour == 0
        ? 12
        : dt.hour;
    final String mi = dt.minute.toString().padLeft(2, '0');
    final String ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$mo/$da/${dt.year} $h:$mi $ampm';
  }

  String _formatDate(DateTime dt) {
    final String mo = dt.month.toString().padLeft(2, '0');
    final String da = dt.day.toString().padLeft(2, '0');
    return '$mo/$da/${dt.year}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color bg = switch (status) {
      'completed' => const Color(0xFFA7D7B5).withValues(alpha: 0.30),
      'cancelled' => cs.errorContainer.withValues(alpha: 0.40),
      _ => cs.primaryContainer.withValues(alpha: 0.50),
    };
    final Color fg = switch (status) {
      'completed' => const Color(0xFF2E7D52),
      'cancelled' => cs.onErrorContainer,
      _ => cs.onPrimaryContainer,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 10),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 12, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
