import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/bill.dart';

class BillCard extends StatelessWidget {
  const BillCard({
    super.key,
    required this.bill,
    required this.onMarkPaid,
    required this.onMarkUnpaid,
    required this.onDelete,
  });

  final BillModel bill;
  final VoidCallback onMarkPaid;
  final VoidCallback onMarkUnpaid;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

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
            // ── Header ───────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.76),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        bill.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Due: ${bill.dueDay.toString().padLeft(2, '0')} of every month',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (bill.assignedPersonName != null) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          'Assigned to: ${bill.assignedPersonName!}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (bill.isPaid && bill.paidByPersonName != null) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          'Paid by: ${bill.paidByPersonName!}',
                          style: textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFA7D7B5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _BillStatusChip(status: bill.displayStatus),
              ],
            ),

            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.50),
            ),
            const SizedBox(height: 12),

            // ── Amount + payment method ───────────────────────────────────
            Row(
              children: <Widget>[
                Expanded(
                  child: _BillMetric(
                    label: 'Amount',
                    value: CurrencyFormatter.format(bill.amount),
                  ),
                ),
                Expanded(
                  child: _BillMetric(
                    label: 'Payment method',
                    value: bill.paymentMethod.isEmpty ? '—' : bill.paymentMethod,
                  ),
                ),
              ],
            ),

            if (bill.isPaid && bill.paidOn != null) ...<Widget>[
              const SizedBox(height: 10),
              _BillMetric(
                label: 'Paid on',
                value: _displayDate(bill.paidOn!),
                valueColor: const Color(0xFFA7D7B5),
              ),
            ],

            if (bill.remarks != null) ...<Widget>[
              const SizedBox(height: 10),
              _BillMetric(
                label: 'Remarks',
                value: bill.remarks!,
              ),
            ],

            const SizedBox(height: 14),

            // ── Actions ──────────────────────────────────────────────────
            Row(
              children: <Widget>[
                if (!bill.isPaid)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onMarkPaid,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Mark Paid'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                if (bill.isPaid)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onMarkUnpaid,
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Mark Unpaid'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: colorScheme.error,
                  ),
                  label: Text(
                    'Delete',
                    style: TextStyle(color: colorScheme.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(
                      color: colorScheme.error.withValues(alpha: 0.50),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _displayDate(DateTime date) {
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$m/$d/${date.year}';
  }
}

// ── Private widgets ───────────────────────────────────────────────────────────

class _BillMetric extends StatelessWidget {
  const _BillMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

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
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: valueColor ?? colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _BillStatusChip extends StatelessWidget {
  const _BillStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      'paid' => const Color(0xFFA7D7B5),
      'overdue' => Theme.of(context).colorScheme.error,
      _ => Theme.of(context).colorScheme.primary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}