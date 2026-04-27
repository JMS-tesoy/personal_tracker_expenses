import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/current_user.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/floating_action_surface.dart';
import '../../../activity/presentation/screens/activity_timeline_screen.dart';
import '../../../loans/domain/loan.dart';
import '../../../loans/presentation/screens/loan_details_screen.dart';
import '../../../loans/presentation/widgets/loan_card.dart';
import '../../../reminders/presentation/screens/reminders_screen.dart';
import '../widgets/recent_transaction_tile.dart';
import '../widgets/summary_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onOpenActivity});

  final VoidCallback? onOpenActivity;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  List<_DashboardTransaction> transactions = [];
  List<LoanModel> loans = [];
  int ignoredInvalidTransactionCount = 0;
  bool hasShownPaydayAlert = false;

  @override
  void initState() {
    super.initState();
    fetchDashboardData();
  }

  Future<void> fetchDashboardData() async {
    try {
      final String userId = requireCurrentUserId();
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month);
      final startOfNextMonth = DateTime(now.year, now.month + 1);

      final categoriesData = await supabase
          .from('categories')
          .select('id, name, type')
          .eq('user_id', userId);
      final categoriesById = {
        for (final category in categoriesData)
          category['id'].toString(): _DashboardCategory.fromMap(
            Map<String, dynamic>.from(category),
          ),
      };

      final transactionsData = await supabase
          .from('transactions')
          .select(
            'id, amount, type, category_id, payment_method, transaction_date, created_at',
          )
          .eq('user_id', userId)
          .gte('transaction_date', databaseDate(startOfMonth))
          .lt('transaction_date', databaseDate(startOfNextMonth))
          .order('created_at', ascending: false);
      final loansData = await supabase
          .from('loans')
          .select()
          .eq('user_id', userId)
          .order('next_due_date', ascending: true);

      final parsedTransactions = transactionsData.map<_DashboardTransaction?>((
        item,
      ) {
        final map = Map<String, dynamic>.from(item);
        final categoryId = map['category_id']?.toString();
        final category = categoriesById[categoryId];

        if (category == null) return null;

        return _DashboardTransaction.fromMap(map, category.name, category.type);
      }).toList();
      final validTransactions = parsedTransactions
          .whereType<_DashboardTransaction>()
          .where((transaction) {
            return transaction.hasValidAmount;
          })
          .toList();

      if (!mounted) return;
      setState(() {
        transactions = validTransactions;
        loans = List<Map<String, dynamic>>.from(
          loansData,
        ).map(LoanModel.fromMap).toList();
        ignoredInvalidTransactionCount =
            parsedTransactions.length - validTransactions.length;
        isLoading = false;
      });

      showPaydayAlertIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      showMessage('Failed to load dashboard.');
    }
  }

  List<_DashboardTransaction> get monthlyTransactions {
    final now = DateTime.now();

    return transactions.where((transaction) {
      return transaction.transactionDate.year == now.year &&
          transaction.transactionDate.month == now.month;
    }).toList();
  }

  double get totalIncome {
    return monthlyTransactions
        .where((transaction) => transaction.isIncome)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double get totalExpense {
    return monthlyTransactions
        .where((transaction) => !transaction.isIncome)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  double get remainingBalance {
    return totalIncome - totalExpense;
  }

  double get currentMonthExpense {
    return monthlyTransactions
        .where((transaction) => !transaction.isIncome)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
  }

  List<_DashboardTransaction> get recentTransactions {
    return monthlyTransactions.take(5).toList();
  }

  List<LoanModel> get activeLoans {
    return loans.where((loan) => !loan.isPaid).toList();
  }

  _PaydayPreview get paydayPreview {
    final today = dateOnly(DateTime.now());
    final payday = nextPaydayDate(today);
    final dueTransactions = monthlyTransactions.where((transaction) {
      final transactionDate = dateOnly(transaction.transactionDate);

      return !transactionDate.isBefore(today) &&
          !transactionDate.isAfter(payday);
    }).toList();
    final incomingSalary = dueTransactions
        .where((transaction) => transaction.isIncome)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
    final expectedIncome = incomingSalary > 0 ? incomingSalary : totalIncome;
    final loanAllocation = activeLoans
        .where((loan) => isLoanDueForPayday(loan, payday))
        .fold(0.0, (sum, loan) => sum + loan.perPaydayAllocation);
    final billAllocation = dueTransactions
        .where((transaction) => transaction.isBill && !transaction.isIncome)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
    final plannedSavings = dueTransactions
        .where((transaction) => transaction.isSavings && !transaction.isIncome)
        .fold(0.0, (sum, transaction) => sum + transaction.amount);
    final recommendedSavings = plannedSavings > 0
        ? plannedSavings
        : expectedIncome * 0.10;
    final totalAllocations =
        loanAllocation + billAllocation + recommendedSavings;

    return _PaydayPreview(
      paydayDate: payday,
      incomingSalary: expectedIncome,
      loans: loanAllocation,
      bills: billAllocation,
      savings: recommendedSavings,
      safeToSpend: expectedIncome - totalAllocations,
      isAlertDay: isPaydayAlertDay(today),
    );
  }

  Future<void> openLoanDetails(LoanModel loan) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LoanDetailsScreen(loan: loan)),
    );

    if (result == true) {
      fetchDashboardData();
    }
  }

  void openReminders() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const RemindersScreen()),
    );
  }

  void openActivityTimeline() {
    if (widget.onOpenActivity != null) {
      widget.onOpenActivity!();
      return;
    }

    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const ActivityTimelineScreen(),
      ),
    );
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  void showPaydayAlertIfNeeded() {
    final preview = paydayPreview;

    if (!preview.isAlertDay || hasShownPaydayAlert) return;

    hasShownPaydayAlert = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Payday tomorrow'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You have ${CurrencyFormatter.format(preview.totalAllocations)} obligations:',
                ),
                const SizedBox(height: 12),
                _PaydayPreviewRow(label: 'Loans', value: preview.loans),
                _PaydayPreviewRow(label: 'Bills', value: preview.bills),
                _PaydayPreviewRow(
                  label: 'Recommended savings',
                  value: preview.savings,
                ),
                const Divider(height: 24),
                _PaydayPreviewRow(
                  label: 'Remaining usable',
                  value: preview.safeToSpend,
                  isStrong: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    });
  }

  Color balanceColor(ColorScheme colorScheme) {
    if (remainingBalance < 0) return colorScheme.error;

    return const Color(0xFFA7D7B5);
  }

  bool isLoanDueForPayday(LoanModel loan, DateTime payday) {
    final nextDueDate = loan.nextDueDate;

    if (nextDueDate == null) return true;

    return !dateOnly(nextDueDate).isAfter(payday);
  }

  bool isPaydayAlertDay(DateTime date) {
    return date.day == 14 || date.day == 29;
  }

  DateTime nextPaydayDate(DateTime date) {
    if (date.day <= 14) {
      return safeDateForMonth(date.year, date.month, 15);
    }

    if (date.day <= 29) {
      return safeDateForMonth(date.year, date.month, 30);
    }

    return safeDateForMonth(date.year, date.month + 1, 15);
  }

  DateTime safeDateForMonth(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    final safeDay = day.clamp(1, lastDay).toInt();

    return DateTime(year, month, safeDay);
  }

  DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String formatType(String value) {
    if (value.isEmpty) return value;

    return value[0].toUpperCase() + value.substring(1);
  }

  String databaseDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  String displayDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$month/$day/${date.year}';
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.76,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 36,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No transactions yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Start by adding your first expense.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDashboardContent() {
    final colorScheme = Theme.of(context).colorScheme;
    final hasTransactionsThisMonth = monthlyTransactions.isNotEmpty;
    final dashboardLoans = activeLoans;
    final hasDashboardData =
        transactions.isNotEmpty || dashboardLoans.isNotEmpty;
    final preview = paydayPreview;

    return RefreshIndicator(
      onRefresh: fetchDashboardData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Payday Tracker',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              // ── Activity Timeline button ─────────────────────────────
              Tooltip(
                message: 'Activity Timeline',
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: FloatingActionSurface(
                    onTap: openActivityTimeline,
                    minHeight: 44,
                    padding: EdgeInsets.zero,
                    child: Icon(
                      Icons.history,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  signOut();
                },
                icon: const Icon(Icons.logout),
                tooltip: 'Sign out',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This month',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          if (!hasDashboardData)
            buildEmptyState()
          else ...[
            DashboardSummaryCard(
              title: 'Available Balance',
              value: CurrencyFormatter.format(remainingBalance),
              icon: Icons.account_balance_wallet_outlined,
              isLarge: true,
              valueColor: balanceColor(colorScheme),
              subtitle: 'Based on recorded income and expenses',
              actionIcon: Icons.notifications_none_outlined,
              actionTooltip: 'Reminders',
              onActionPressed: openReminders,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DashboardSummaryCard(
                    title: 'Income',
                    value: CurrencyFormatter.format(totalIncome),
                    icon: Icons.arrow_downward,
                    valueColor: const Color(0xFFA7D7B5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DashboardSummaryCard(
                    title: 'Expense',
                    value: CurrencyFormatter.format(totalExpense),
                    icon: Icons.arrow_upward,
                    valueColor: colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DashboardSummaryCard(
              title: 'This Month Spending',
              value: CurrencyFormatter.format(currentMonthExpense),
              icon: Icons.calendar_month_outlined,
              valueColor: colorScheme.error,
            ),
            const SizedBox(height: 12),
            _PaydayPreviewCard(
              preview: preview,
              paydayText: displayDate(preview.paydayDate),
            ),
            if (dashboardLoans.isNotEmpty) ...[
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Loan Installments',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${dashboardLoans.length} active',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...dashboardLoans.map((loan) {
                return LoanCard(loan: loan, onTap: () => openLoanDetails(loan));
              }),
            ],
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Recent Transactions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${recentTransactions.length} shown',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasTransactionsThisMonth)
              Text(
                'No transactions recorded this month.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...recentTransactions.map((transaction) {
                return RecentTransactionTile(
                  categoryName: transaction.categoryName,
                  categoryType: formatType(transaction.categoryType),
                  paymentMethod: transaction.paymentMethod,
                  amount: CurrencyFormatter.format(transaction.amount),
                  isIncome: transaction.isIncome,
                );
              }),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : buildDashboardContent(),
      ),
    );
  }
}

class _DashboardTransaction {
  const _DashboardTransaction({
    required this.amount,
    required this.transactionType,
    required this.categoryName,
    required this.categoryType,
    required this.paymentMethod,
    required this.transactionDate,
  });

  final double amount;
  final String transactionType;
  final String categoryName;
  final String categoryType;
  final String paymentMethod;
  final DateTime transactionDate;

  bool get hasValidAmount {
    return amount > 0 && amount <= AppConstants.maxTransactionAmount;
  }

  bool get isIncome {
    final normalizedCategoryType = categoryType.toLowerCase();

    if (normalizedCategoryType.isNotEmpty) {
      return normalizedCategoryType == 'income';
    }

    return transactionType.toLowerCase() == 'income';
  }

  bool get isSavings {
    final normalizedCategoryName = categoryName.toLowerCase();
    final normalizedCategoryType = categoryType.toLowerCase();

    return normalizedCategoryType == 'savings' ||
        normalizedCategoryName.contains('saving');
  }

  bool get isBill {
    final normalizedCategoryName = categoryName.toLowerCase();
    final normalizedCategoryType = categoryType.toLowerCase();

    return normalizedCategoryType == 'bill' ||
        normalizedCategoryType == 'bills' ||
        normalizedCategoryName.contains('bill');
  }

  factory _DashboardTransaction.fromMap(
    Map<String, dynamic> map,
    String categoryName,
    String categoryType,
  ) {
    return _DashboardTransaction(
      amount: (map['amount'] as num).toDouble(),
      transactionType: map['type'].toString(),
      categoryName: categoryName,
      categoryType: categoryType,
      paymentMethod: map['payment_method'].toString(),
      transactionDate: DateTime.parse(map['transaction_date'].toString()),
    );
  }
}

class _DashboardCategory {
  const _DashboardCategory({required this.name, required this.type});

  final String name;
  final String type;

  factory _DashboardCategory.fromMap(Map<String, dynamic> map) {
    return _DashboardCategory(
      name: map['name'].toString(),
      type: map['type'].toString(),
    );
  }
}

class _PaydayPreview {
  const _PaydayPreview({
    required this.paydayDate,
    required this.incomingSalary,
    required this.loans,
    required this.bills,
    required this.savings,
    required this.safeToSpend,
    required this.isAlertDay,
  });

  final DateTime paydayDate;
  final double incomingSalary;
  final double loans;
  final double bills;
  final double savings;
  final double safeToSpend;
  final bool isAlertDay;

  double get totalAllocations {
    return loans + bills + savings;
  }
}

class _PaydayPreviewCard extends StatelessWidget {
  const _PaydayPreviewCard({required this.preview, required this.paydayText});

  final _PaydayPreview preview;
  final String paydayText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.78),
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
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.76),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.notifications_active_outlined,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payday Preview',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        preview.isAlertDay
                            ? 'Payday tomorrow'
                            : 'Next payday: $paydayText',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _PaydayPreviewRow(
              label: 'Incoming Salary',
              value: preview.incomingSalary,
            ),
            const SizedBox(height: 10),
            Text(
              'Allocations',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            _PaydayPreviewRow(label: 'Loans', value: preview.loans),
            _PaydayPreviewRow(label: 'Bills', value: preview.bills),
            _PaydayPreviewRow(label: 'Savings', value: preview.savings),
            const Divider(height: 24),
            _PaydayPreviewRow(
              label: 'Safe to spend',
              value: preview.safeToSpend,
              isStrong: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaydayPreviewRow extends StatelessWidget {
  const _PaydayPreviewRow({
    required this.label,
    required this.value,
    this.isStrong = false,
  });

  final String label;
  final double value;
  final bool isStrong;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final valueColor = isStrong && value < 0
        ? colorScheme.error
        : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: isStrong ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              CurrencyFormatter.format(value),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontWeight: isStrong ? FontWeight.w900 : FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
