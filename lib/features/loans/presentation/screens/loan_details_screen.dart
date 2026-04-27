import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/current_user.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../activity/data/repositories/activity_log_repository.dart';
import '../../../reminders/presentation/widgets/reminder_form_sheet.dart';
import '../../domain/loan.dart';

class LoanDetailsScreen extends StatefulWidget {
  const LoanDetailsScreen({
    super.key,
    required this.loan,
    this.onBack,
    this.onLoanChanged,
  });

  final LoanModel loan;
  final VoidCallback? onBack;
  final ValueChanged<LoanModel>? onLoanChanged;

  @override
  State<LoanDetailsScreen> createState() => _LoanDetailsScreenState();
}

class _LoanDetailsScreenState extends State<LoanDetailsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  late LoanModel loan;
  bool isSaving = false;
  bool isLoadingContributions = true;
  List<_LoanPerson> people = <_LoanPerson>[];
  List<_LoanContributionSummary> contributionSummary =
      <_LoanContributionSummary>[];

  @override
  void initState() {
    super.initState();
    loan = widget.loan;
    _loadPeople();
    _loadContributionSummary();
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
  /// - day == 15  → 30th of same month (clamped to last day)
  /// - day >= 30  → 15th of next month
  DateTime _nextPaydayDueDate(DateTime current) {
    if (current.day == 15) {
      final int lastDay = DateTime(current.year, current.month + 1, 0).day;
      final int safeDay = 30.clamp(1, lastDay);
      return DateTime(current.year, current.month, safeDay);
    }
    final DateTime nextMonth = DateTime(current.year, current.month + 1);
    return DateTime(nextMonth.year, nextMonth.month, 15);
  }

  Future<void> _confirmAndMarkPaid() async {
    if (loan.isPaid) {
      _showMessage('This loan is already fully paid.');
      return;
    }

    if (people.isEmpty) {
      _showMessage('Add a person first before recording a loan payment.');
      return;
    }

    if (loan.paidPaydays >= loan.totalPaydays) {
      final String userId = requireCurrentUserId();
      await supabase
          .from('loans')
          .update(<String, dynamic>{'status': 'paid', 'remaining_balance': 0.0})
          .eq('id', loan.id)
          .eq('user_id', userId);
      await ActivityLogRepository.instance.createLog(
        targetType: 'loan',
        action: 'marked_paid',
        title: 'Loan marked paid',
        targetId: loan.id,
        description: '${loan.name} was marked as fully paid.',
        metadata: <String, dynamic>{
          'loan_name': loan.name,
          'remaining_balance': 0.0,
        },
      );
      if (!mounted) return;
      final LoanModel updatedLoan = loan.copyWith(
        remainingBalance: 0.0,
        status: 'paid',
      );
      loan = updatedLoan;
      widget.onLoanChanged?.call(updatedLoan);
      _pop();
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
    final bool isPartialFinalPayment =
        loan.remainingBalance > 0 &&
        loan.remainingBalance < loan.perPaydayAllocation;
    final double paymentAmount = isPartialFinalPayment
        ? loan.remainingBalance
        : loan.perPaydayAllocation;

    final String? paidByPersonId = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        String selectedPersonId = people.first.id;

        return StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Confirm Payday Payment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Mark the $dueDateLabel payday payment as paid?'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPersonId,
                    decoration: const InputDecoration(labelText: 'Paid by'),
                    items: people
                        .map(
                          (_LoanPerson person) => DropdownMenuItem<String>(
                            value: person.id,
                            child: Text(person.name),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      if (value == null) return;
                      setDialogState(() => selectedPersonId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  _DialogRow(
                    label: 'Payday payment',
                    value: CurrencyFormatter.format(paymentAmount),
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
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, selectedPersonId),
                  child: const Text('Confirm Payment'),
                ),
              ],
            );
          },
        );
      },
    );

    if (paidByPersonId == null || !mounted) return;

    await _markPaydayAsPaid(
      newPaidPaydays,
      newBalance,
      isFinal,
      upcomingDueDate,
      paidByPersonId,
      paymentAmount,
    );
  }

  Future<void> _markPaydayAsPaid(
    int newPaidPaydays,
    double newBalance,
    bool isFinal,
    DateTime? nextDueDate,
    String paidByPersonId,
    double paymentAmount,
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

      await _recordContribution(
        personId: paidByPersonId,
        amount: paymentAmount,
      );
      await ActivityLogRepository.instance.createLog(
        targetType: 'loan',
        action: isFinal ? 'marked_paid' : 'payment_recorded',
        title: isFinal ? 'Loan marked paid' : 'Loan payment recorded',
        targetId: loan.id,
        personId: paidByPersonId,
        description: isFinal
            ? '${loan.name} was fully paid.'
            : '${loan.name} payment was recorded.',
        metadata: <String, dynamic>{
          'loan_name': loan.name,
          'amount': paymentAmount,
          'paid_paydays': newPaidPaydays,
          'remaining_balance': newBalance,
        },
      );

      if (!mounted) return;
      final LoanModel updatedLoan = loan.copyWith(
        remainingBalance: newBalance,
        status: newStatus,
        paidPaydays: newPaidPaydays,
        nextDueDate: nextDueDate,
      );
      loan = updatedLoan;
      widget.onLoanChanged?.call(updatedLoan);
      _pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => isSaving = false);
      _showMessage('Failed to update loan or record contributor.');
    }
  }

  Future<void> _loadPeople() async {
    try {
      final String userId = requireCurrentUserId();
      final List<dynamic> rows = await supabase
          .from('people')
          .select('id, name')
          .eq('user_id', userId)
          .order('name');

      if (!mounted) return;
      setState(() {
        people = rows
            .map(
              (dynamic row) =>
                  _LoanPerson.fromMap(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      _showMessage('Failed to load people.');
    }
  }

  Future<void> _loadContributionSummary() async {
    setState(() => isLoadingContributions = true);

    try {
      final String userId = requireCurrentUserId();
      final List<dynamic> peopleRows = await supabase
          .from('people')
          .select('id, name')
          .eq('user_id', userId);
      final Map<String, String> namesById = <String, String>{
        for (final dynamic row in peopleRows)
          (row as Map<String, dynamic>)['id'].toString(): row['name']
              .toString(),
      };

      final List<dynamic> contributionRows = await supabase
          .from('loan_payment_contributions')
          .select('person_id, amount')
          .eq('user_id', userId)
          .eq('loan_id', loan.id);

      final Map<String, double> totalsByPersonId = <String, double>{};
      final Map<String, int> countsByPersonId = <String, int>{};

      for (final dynamic row in contributionRows) {
        final Map<String, dynamic> map = Map<String, dynamic>.from(row as Map);
        final String personId = map['person_id'].toString();
        final double amount = LoanModel.parseAmount(map['amount']);

        totalsByPersonId[personId] = (totalsByPersonId[personId] ?? 0) + amount;
        countsByPersonId[personId] = (countsByPersonId[personId] ?? 0) + 1;
      }

      final List<_LoanContributionSummary> summary =
          totalsByPersonId.entries
              .map(
                (MapEntry<String, double> entry) => _LoanContributionSummary(
                  personName: namesById[entry.key] ?? 'Unknown person',
                  totalAmount: entry.value,
                  paymentCount: countsByPersonId[entry.key] ?? 0,
                ),
              )
              .toList()
            ..sort(
              (_LoanContributionSummary a, _LoanContributionSummary b) =>
                  b.totalAmount.compareTo(a.totalAmount),
            );

      if (!mounted) return;
      setState(() {
        contributionSummary = summary;
        isLoadingContributions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoadingContributions = false);
    }
  }

  Future<void> _recordContribution({
    required String personId,
    required double amount,
  }) async {
    final String userId = requireCurrentUserId();
    await supabase.from('loan_payment_contributions').insert(<String, dynamic>{
      'user_id': userId,
      'loan_id': loan.id,
      'person_id': personId,
      'amount': amount,
      'paid_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Handles both inline nav (onBack) and push nav (Navigator.pop).
  void _pop() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.pop(context, true);
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
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
        title: const Text('Loan Details'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add_alert_outlined),
            tooltip: 'Add reminder',
            onPressed: () async {
              final result = await showReminderFormSheet(
                context,
                targetType: 'loan',
                targetId: loan.id,
                prefillTitle: '${loan.name} payment',
                prefillDueAt: loan.nextDueDate,
              );
              if (result == null) return;
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
            },
          ),
        ],
      ),
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
                    if (loan.isPaid ||
                        contributionSummary.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      Text(
                        'Payment contributors',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (isLoadingContributions)
                        const Center(child: CircularProgressIndicator())
                      else if (contributionSummary.isEmpty)
                        Text(
                          'No contributor records yet.',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        ...contributionSummary.asMap().entries.map(
                          (MapEntry<int, _LoanContributionSummary> entry) =>
                              _ContributionRow(
                                summary: entry.value,
                                isTopContributor: entry.key == 0,
                              ),
                        ),
                    ],
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
            const SizedBox(height: 18),
            Center(
              child: FilledButton(
                onPressed: loan.isPaid || isSaving ? null : _confirmAndMarkPaid,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
                  disabledBackgroundColor: colorScheme.onSurface.withValues(
                    alpha: 0.08,
                  ),
                  foregroundColor: colorScheme.primary,
                  disabledForegroundColor: colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.62),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: colorScheme.primary.withValues(alpha: 0.22),
                    ),
                  ),
                ),
                child: Text(
                  _buttonLabel(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
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

class _ContributionRow extends StatelessWidget {
  const _ContributionRow({
    required this.summary,
    required this.isTopContributor,
  });

  final _LoanContributionSummary summary;
  final bool isTopContributor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        summary.personName,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isTopContributor) ...<Widget>[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFA7D7B5,
                          ).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Most paid',
                          style: TextStyle(
                            color: Color(0xFFA7D7B5),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${summary.paymentCount} payment${summary.paymentCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            CurrencyFormatter.format(summary.totalAmount),
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _LoanPerson {
  const _LoanPerson({required this.id, required this.name});

  final String id;
  final String name;

  factory _LoanPerson.fromMap(Map<String, dynamic> map) {
    return _LoanPerson(id: map['id'].toString(), name: map['name'].toString());
  }
}

class _LoanContributionSummary {
  const _LoanContributionSummary({
    required this.personName,
    required this.totalAmount,
    required this.paymentCount,
  });

  final String personName;
  final double totalAmount;
  final int paymentCount;
}
