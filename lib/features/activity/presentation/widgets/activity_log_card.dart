import 'package:flutter/material.dart';

import '../../data/models/activity_log_model.dart';

class ActivityLogCard extends StatelessWidget {
  const ActivityLogCard({super.key, required this.log});

  final ActivityLogModel log;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final _ActivityStyle style = _styleFor(log, colors);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Column(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(style.icon, size: 20, color: style.color),
            ),
            Container(
              width: 2,
              height: 54,
              color: colors.outlineVariant.withValues(alpha: 0.65),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.75),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          log.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _TypePill(label: _prettyTargetType(log.targetType)),
                    ],
                  ),
                  if (log.description != null &&
                      log.description!.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 5),
                    Text(
                      log.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      if (log.personName != null &&
                          log.personName!.trim().isNotEmpty)
                        _MetaPill(
                          icon: Icons.person_outline,
                          label: log.personName!,
                        ),
                      if (log.targetName != null &&
                          log.targetName!.trim().isNotEmpty)
                        _MetaPill(
                          icon: _targetIcon(log.targetType),
                          label: log.targetName!,
                        ),
                      if (log.fileNameFromMetadata != null)
                        _MetaPill(
                          icon: Icons.image_outlined,
                          label: log.fileNameFromMetadata!,
                        ),
                      if (log.deviceName != null &&
                          log.deviceName!.trim().isNotEmpty)
                        _MetaPill(
                          icon: Icons.phone_android_outlined,
                          label: log.devicePlatform != null &&
                                  log.devicePlatform!.trim().isNotEmpty
                              ? '${log.deviceName} • ${log.devicePlatform}'
                              : log.deviceName!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.schedule_outlined,
                        size: 13,
                        color: colors.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateTime(log.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.outline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _prettyAction(log.action),
                        style: TextStyle(
                          fontSize: 11,
                          color: style.color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  _ActivityStyle _styleFor(ActivityLogModel log, ColorScheme colors) {
    final String action = log.action;
    final String targetType = log.targetType;

    final IconData icon = switch (action) {
      'created' => Icons.add_circle_outline,
      'updated' => Icons.edit_outlined,
      'deleted' => Icons.delete_outline,
      'marked_paid' => Icons.check_circle_outline,
      'marked_unpaid' => Icons.undo_outlined,
      'archived' => Icons.archive_outlined,
      'payment_recorded' => Icons.payments_outlined,
      'proof_uploaded' => Icons.upload_file_outlined,
      'reminder_created' => Icons.add_alert_outlined,
      'reminder_completed' => Icons.notifications_active_outlined,
      'reminder_cancelled' => Icons.notifications_off_outlined,
      'person_assigned' => Icons.person_add_outlined,
      _ => _targetIcon(targetType),
    };

    final Color color = switch (action) {
      'deleted' || 'reminder_cancelled' => colors.error,
      'marked_paid' ||
      'reminder_completed' ||
      'payment_recorded' ||
      'proof_uploaded' =>
        const Color(0xFF2E7D52),
      'marked_unpaid' || 'archived' => colors.tertiary,
      _ => colors.primary,
    };

    return _ActivityStyle(icon: icon, color: color);
  }

  static IconData _targetIcon(String targetType) {
    return switch (targetType) {
      'bill' => Icons.receipt_long_outlined,
      'loan' => Icons.account_balance_outlined,
      'person' => Icons.person_outline,
      'people_group' => Icons.groups_outlined,
      'category' => Icons.category_outlined,
      'transaction' => Icons.swap_horiz_outlined,
      'reminder' => Icons.notifications_outlined,
      'payment_proof' => Icons.image_outlined,
      _ => Icons.info_outline,
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

  String _prettyTargetType(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((String part) => part.trim().isNotEmpty)
        .map(
          (String part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _prettyAction(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((String part) => part.trim().isNotEmpty)
        .map(
          (String part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: colors.onSurfaceVariant),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityStyle {
  const _ActivityStyle({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;
}