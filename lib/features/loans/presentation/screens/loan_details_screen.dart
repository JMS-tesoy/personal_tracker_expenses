import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/current_user.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/loan.dart';

class LoanDetailsScreen extends StatefulWidget {
  const LoanDetailsScreen({super.key, required this.loan});

  final LoanModel loan;

  @override
  State<LoanDetailsScreen> createState() => _LoanDetailsScreenState();
}

class _LoanDetailsScreenState extends State<LoanDetailsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  late LoanModel loan;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    loan = widget.loan;
  }

  String _friendlyDate(DateTime date) {
    const List<String> months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _buttonLabel() {
    if (loan.isPaid) return 'Loan Fully Paid';
    if (isSaving) return 'Updating...';
    if (loan.nextDueDate != null) {
      return 'Mark ${_friendlyDate(loan.nextDueDate!)} Payment as Paid';
    }
    return 'Mark Payment as Paid';
  }

  /// Advance next_due_date by one payday:
  /// - day == 15 → 30th of same month (clamped to last day)
  /// - day >= 30 → 15th of next month
  DateTime _nextPaydayDueDate(DateTime current) {
    if (current.day == 15) {
      final int lastDay = DateTime(current.year, current.month + 1, 0).day;
      final int safeDay = 30.clamp(1, lastDay);
      return DateTime(current.year, current.month, safeDay);
    }
    // day is 30 or end-of-month equivalent → move to 15th of next month
    final DateTime nextMonth = DateTime(current.year, current.month + 1);
    return DateTime(nextMonth.year, nextMonth.month, 15);
  }

  Future<void> _confirmAndMarkPaid() async {
    if (loan.isPaid) {
      _showMessage('This loan is already fully paid.');
      return;
    }

    if (loan.paidPaydays >= loan.totalPaydays) {
      // Edge-case: paydays exhausted but status not yet updated.
      final String userId = requireCurrentUserId();
      await supabase
          .from('loans')
          .update(<String, dynamic>{'status': 'paid', 'remaining_balance': 0.0})
          .eq('id', loan.id)
          .eq('user_id', userId);
      if (!mounted) return;
      Navigator.pop(context, true);
      return;
    }

    final String dueDateLabel = loan.nextDueDate != null
        ? _friendlyDate(loan.nextDueDate!)
        : 'next payday';

    final int newPaidPaydays = loan.paidPaydays + 1;
    final bool isFinal = newPaidPaydays >= loan.totalPaydays;
    final double rawBalance = loan.remainingBalance - loan.perPaydayAllocation;
    final double newBalance = isFinal
        ? 0.0
        : rawBalance.clamp(0.0, double.infinity);

    final DateTime? upcomingDueDate = loan.nextDueDate != null
        ? _nextPaydayDueDate(loan.nextDueDate!)
        : null;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Confirm Payday Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Mark the $dueDateLabel payday payment as paid?'),
              const SizedBox(height: 16),
              _DialogRow(
                label: 'Payday payment',
                value: CurrencyFormatter.format(loan.perPaydayAllocation),
              ),
              _DialogRow(
                label: 'Remaining after',
                value: CurrencyFormatter.format(newBalance),
              ),
              _DialogRow(
                label: 'Payday progress',
                value: '$newPaidPaydays of ${loan.totalPaydays} payments',
              ),
              if (upcomingDueDate != null && !isFinal)
                _DialogRow(
                  label: 'Next due date',
                  value: _displayDate(upcomingDueDate),
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm Payment'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await _markPaydayAsPaid(
      newPaidPaydays,
      newBalance,
      isFinal,
      upcomingDueDate,
    );
  }

  Future<void> _markPaydayAsPaid(
    int newPaidPaydays,
    double newBalance,
    bool isFinal,
    DateTime? nextDueDate,
  ) async {
    setState(() => isSaving = true);

    try {
      final String userId = requireCurrentUserId();
      final String newStatus = isFinal ? 'paid' : 'active';
      final Map<String, dynamic> updates = <String, dynamic>{
        'paid_paydays': newPaidPaydays,
        'remaining_balance': newBalance,
        'status': newStatus,
      };

      if (nextDueDate != null && !isFinal) {
        updates['next_due_date'] = _toDbDate(nextDueDate);
      }

      await supabase
          .from('loans')
          .update(updates)
          .eq('id', loan.id)
          .eq('user_id', userId);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => isSaving = false);
      _showMessage('Failed to update loan.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _toDbDate(DateTime date) {
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  String _displayDate(DateTime date) {
    final String m = date.month.toString().padLeft(2, '0');
    final String d = date.day.toString().padLeft(2, '0');
    return '$m/$d/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final double paidAmount = loan.originalAmount - loan.remainingBalance;

    return Scaffold(
      appBar: AppBar(title: const Text('Loan Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.78,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.86),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            loan.name,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        _StatusText(status: loan.displayStatus),
                      ],
                    ),
                    if (loan.lender != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        loan.lender!,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    _DetailRow(
                      label: 'Original amount',
                      value: CurrencyFormatter.format(loan.originalAmount),
                    ),
                    _DetailRow(
                      label: 'Remaining balance',
                      value: CurrencyFormatter.format(loan.remainingBalance),
                    ),
                    _DetailRow(
                      label: 'Monthly installment',
                      value: CurrencyFormatter.format(loan.monthlyInstallment),
                    ),
                    _DetailRow(
                      label: 'Next payday payment',
                      value: CurrencyFormatter.format(loan.perPaydayAllocation),
                    ),
                    const _DetailRow(
                      label: 'Payday schedule',
                      value: '15th and 30th',
                    ),
                    _DetailRow(
                      label: 'Loan progress',
                      value:
                          '${CurrencyFormatter.format(paidAmount)} of ${CurrencyFormatter.format(loan.originalAmount)} paid',
                    ),
                    _DetailRow(
                      label: 'Payday progress',
                      value:
                          '${loan.paidPaydays} of ${loan.totalPaydays} payments completed',
                    ),
                    if (loan.startDate != null)
                      _DetailRow(
                        label: 'Start date',
                        value: _displayDate(loan.startDate!),
                      ),
                    if (loan.nextDueDate != null)
                      _DetailRow(
                        label: 'Next due date',
                        value: _displayDate(loan.nextDueDate!),
                      ),
                    if (loan.notes != null) ...<Widget>[
                      const SizedBox(height: 14),
                      Text(
                        'Notes',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(loan.notes!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: AppButton(
            label: _buttonLabel(),
            onPressed: loan.isPaid || isSaving ? null : _confirmAndMarkPaid,
          ),
        ),
      ),
    );
  }
}

// ── Private widgets ───────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogRow extends StatelessWidget {
  const _DialogRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      'paid' => const Color(0xFFA7D7B5),
      'overdue' => Theme.of(context).colorScheme.error,
      _ => Theme.of(context).colorScheme.primary,
    };

    return Text(
      status.toUpperCase(),
      style: TextStyle(color: color, fontWeight: FontWeight.w900),
    );
  }
}
