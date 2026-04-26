import 'package:flutter/material.dart';

import '../../data/models/activity_log_model.dart';

class ActivityLogCard extends StatelessWidget {
  const ActivityLogCard({super.key, required this.log});

  final ActivityLogModel log;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Timeline line + icon
        Column(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _iconColor(log.action, colors).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _icon(log.action, log.targetType),
                size: 18,
                color: _iconColor(log.action, colors),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      log.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      log.targetType,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              if (log.description != null &&
                  log.description!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 3),
                Text(
                  log.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                _formatDateTime(log.createdAt),
                style: TextStyle(fontSize: 11, color: colors.outline),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  IconData _icon(String action, String targetType) {
    return switch (action) {
      'created' => Icons.add_circle_outline,
      'updated' => Icons.edit_outlined,
      'deleted' => Icons.delete_outline,
      'marked_paid' => Icons.check_circle_outline,
      'marked_unpaid' => Icons.undo_outlined,
      'proof_uploaded' => Icons.upload_file_outlined,
      'reminder_created' => Icons.add_alert_outlined,
      'reminder_completed' => Icons.notifications_active_outlined,
      'reminder_cancelled' => Icons.notifications_off_outlined,
      'person_assigned' => Icons.person_add_outlined,
      _ => switch (targetType) {
        'bill' => Icons.receipt_long_outlined,
        'loan' => Icons.account_balance_outlined,
        'person' => Icons.person_outline,
        'reminder' => Icons.notifications_outlined,
        'payment_proof' => Icons.image_outlined,
        _ => Icons.info_outline,
      },
    };
  }

  Color _iconColor(String action, ColorScheme colors) {
    return switch (action) {
      'deleted' || 'reminder_cancelled' => colors.error,
      'marked_paid' ||
      'reminder_completed' ||
      'proof_uploaded' => const Color(0xFFA7D7B5),
      'marked_unpaid' => colors.tertiary,
      _ => colors.primary,
    };
  }

  String _formatDateTime(DateTime dt) {
    final String mo = dt.month.toString().padLeft(2, '0');
    final String da = dt.day.toString().padLeft(2, '0');
    final int hour = dt.hour > 12
        ? dt.hour - 12
        : dt.hour == 0
        ? 12
        : dt.hour;
    final String min = dt.minute.toString().padLeft(2, '0');
    final String ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$mo/$da/${dt.year}  $hour:$min $ampm';
  }
}
