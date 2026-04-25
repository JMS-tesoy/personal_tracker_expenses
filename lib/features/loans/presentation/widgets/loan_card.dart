import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../domain/loan.dart';

class LoanCard extends StatelessWidget {
  const LoanCard({super.key, required this.loan, required this.onTap});

  final LoanModel loan;
  final VoidCallback onTap;

  String _displayDate(DateTime date) {
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$m/$d/${date.year}';
  }

  String get _progressText {
    if (loan.isPaid) {
      return '${loan.totalPaydays} of ${loan.totalPaydays} payments paid';
    }
    return '${loan.paidPaydays} of ${loan.totalPaydays} payments paid';
  }

  String get _nextPaymentText {
    if (loan.isPaid) return 'Fully paid';
    final String amount = CurrencyFormatter.format(loan.perPaydayAllocation);
    if (loan.nextDueDate != null) {
      return '$amount due ${_displayDate(loan.nextDueDate!)}';
    }
    return amount;
  }

  String get _remainingBalanceText {
    if (loan.isPaid) return CurrencyFormatter.format(0);
    return CurrencyFormatter.format(loan.remainingBalance);
  }

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
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // ── Header row ──────────────────────────────────────────────
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
                      Icons.account_balance_outlined,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          loan.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${CurrencyFormatter.format(loan.perPaydayAllocation)} per payday  •  15th & 30th',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (loan.lender != null) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            loan.lender!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _LoanStatusChip(status: loan.displayStatus),
                ],
              ),

              const SizedBox(height: 16),
              Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.50),
              ),
              const SizedBox(height: 14),

              // ── Metrics ─────────────────────────────────────────────────
              Row(
                children: <Widget>[
                  Expanded(
                    child: _LoanMetric(
                      label: 'Remaining balance',
                      value: _remainingBalanceText,
                      valueColor: loan.isPaid
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.onSurface,
                    ),
                  ),
                  Expanded(
                    child: _LoanMetric(
                      label: 'Payment progress',
                      value: _progressText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _LoanMetric(
                label: 'Next payment',
                value: _nextPaymentText,
                valueColor: loan.isPaid
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Private widgets ───────────────────────────────────────────────────────────

class _LoanMetric extends StatelessWidget {
  const _LoanMetric({
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

class _LoanStatusChip extends StatelessWidget {
  const _LoanStatusChip({required this.status});

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
