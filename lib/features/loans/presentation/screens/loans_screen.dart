import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/loan.dart';
import '../widgets/loan_card.dart';
import 'add_loan_screen.dart';
import 'loan_details_screen.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;

  late final TabController _tabController;
  late final StreamSubscription<List<Map<String, dynamic>>> _subscription;

  bool isLoading = true;
  List<LoanModel> _activeLoans = <LoanModel>[];
  List<LoanModel> _paidLoans = <LoanModel>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _subscribeToLoans();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subscription.cancel();
    super.dispose();
  }

  void _subscribeToLoans() {
    _subscription = supabase
        .from('loans')
        .stream(primaryKey: <String>['id'])
        .order('created_at', ascending: false)
        .listen(
          (List<Map<String, dynamic>> data) {
            if (!mounted) return;
            final List<LoanModel> all =
                data.map(LoanModel.fromMap).toList();
            setState(() {
              _activeLoans =
                  all.where((LoanModel l) => !l.isPaid).toList();
              _paidLoans =
                  all.where((LoanModel l) => l.isPaid).toList();
              isLoading = false;
            });
          },
          onError: (_) {
            if (!mounted) return;
            setState(() => isLoading = false);
            _showMessage('Failed to load loans.');
          },
        );
  }

  Future<void> _openAddLoan() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const AddLoanScreen()),
    );
  }

  Future<void> _openLoanDetails(LoanModel loan) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => LoanDetailsScreen(loan: loan)),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildLoanList(List<LoanModel> loans, String emptyMessage) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (loans.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 64, 16, 96),
        children: <Widget>[
          Icon(
            Icons.account_balance_outlined,
            size: 52,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: loans.map((LoanModel loan) {
        return LoanCard(loan: loan, onTap: () => _openLoanDetails(loan));
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Loans',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Payday planning for every 15th and 30th',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Tabs ─────────────────────────────────────────────────────
            TabBar(
              controller: _tabController,
              tabs: <Tab>[
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('Active'),
                      if (!isLoading && _activeLoans.isNotEmpty) ...<Widget>[
                        const SizedBox(width: 6),
                        _CountBadge(
                          count: _activeLoans.length,
                          color: colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('Paid'),
                      if (!isLoading && _paidLoans.isNotEmpty) ...<Widget>[
                        const SizedBox(width: 6),
                        _CountBadge(
                          count: _paidLoans.length,
                          color: const Color(0xFFA7D7B5),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // ── Tab content ──────────────────────────────────────────────
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: <Widget>[
                        _buildLoanList(_activeLoans, 'No active loans'),
                        _buildLoanList(_paidLoans, 'No paid loans yet'),
                      ],
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddLoan,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ── Private widgets ───────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}