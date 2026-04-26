import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/current_user.dart';
import '../../domain/bill.dart';
import '../widgets/bill_card.dart';
import 'add_bill_screen.dart';
import 'bill_details_screen.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;

  late final StreamSubscription<List<Map<String, dynamic>>> _subscription;
  late final TabController _tabController;

  bool isLoading = true;
  BillModel? _selectedBill;
  List<BillModel> _unpaid = <BillModel>[];
  List<BillModel> _overdue = <BillModel>[];
  List<BillModel> _paid = <BillModel>[];

  // People name lookup map: id -> name
  Map<String, String> _peopleNames = <String, String>{};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPeopleAndSubscribe();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPeopleAndSubscribe() async {
    try {
      final String userId = requireCurrentUserId();
      final List<dynamic> people = await supabase
          .from('people')
          .select('id, name')
          .eq('user_id', userId);
      _peopleNames = <String, String>{
        for (final dynamic p in people)
          (p as Map<String, dynamic>)['id'].toString(): p['name'].toString(),
      };
    } catch (_) {}
    _subscribe();
  }

  void _subscribe() {
    final String userId = requireCurrentUserId();
    _subscription = supabase
        .from('bills')
        .stream(primaryKey: <String>['id'])
        .eq('user_id', userId)
        .order('due_day', ascending: true)
        .listen(
          (List<Map<String, dynamic>> data) {
            if (!mounted) return;
            final List<BillModel> all = data.map((Map<String, dynamic> row) {
              // Inject resolved names into the map before parsing
              final Map<String, dynamic> enriched = Map<String, dynamic>.from(
                row,
              );
              enriched['assigned_person_name'] =
                  _peopleNames[row['assigned_person_id']?.toString()];
              enriched['paid_by_person_name'] =
                  _peopleNames[row['paid_by_person_id']?.toString()];
              return BillModel.fromMap(enriched);
            }).toList();

            setState(() {
              _unpaid = all
                  .where((BillModel b) => !b.isPaid && !b.isOverdue)
                  .toList();
              _overdue = all
                  .where((BillModel b) => !b.isPaid && b.isOverdue)
                  .toList();
              _paid = all.where((BillModel b) => b.isPaid).toList();
              isLoading = false;
            });
          },
          onError: (_) {
            if (!mounted) return;
            setState(() => isLoading = false);
            _showMessage('Failed to load bills.');
          },
        );
  }

  Future<void> _markPaid(BillModel bill) async {
    final String today = _toDbDate(DateTime.now());
    try {
      final String userId = requireCurrentUserId();
      await supabase
          .from('bills')
          .update(<String, dynamic>{'status': 'paid', 'paid_on': today})
          .eq('id', bill.id)
          .eq('user_id', userId);
    } catch (_) {
      _showMessage('Failed to mark bill as paid.');
    }
  }

  Future<void> _markUnpaid(BillModel bill) async {
    try {
      final String userId = requireCurrentUserId();
      await supabase
          .from('bills')
          .update(<String, dynamic>{'status': 'unpaid', 'paid_on': null})
          .eq('id', bill.id)
          .eq('user_id', userId);
    } catch (_) {
      _showMessage('Failed to mark bill as unpaid.');
    }
  }

  Future<void> _confirmDelete(BillModel bill) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete Bill'),
        content: Text('Delete "${bill.name}"? This cannot be undone.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final String userId = requireCurrentUserId();
      await supabase
          .from('bills')
          .delete()
          .eq('id', bill.id)
          .eq('user_id', userId);
    } catch (_) {
      _showMessage('Failed to delete bill.');
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

  Widget _buildSection(String title, List<BillModel> bills, Color titleColor) {
    if (bills.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 4),
          child: Row(
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: titleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${bills.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...bills.map(
          (BillModel bill) => BillCard(
            bill: bill,
            onOpen: () => setState(() => _selectedBill = bill),
            onMarkPaid: () => _markPaid(bill),
            onMarkUnpaid: () => _markUnpaid(bill),
            onDelete: () => _confirmDelete(bill),
          ),
        ),
      ],
    );
  }

  Widget _buildUnpaidTab() {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool empty = _unpaid.isEmpty && _overdue.isEmpty;

    if (empty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.check_circle_outline,
              size: 56,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No unpaid bills',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              "You're all caught up!",
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: <Widget>[
        _buildSection('Overdue', _overdue, colors.error),
        _buildSection('Unpaid', _unpaid, colors.primary),
      ],
    );
  }

  Widget _buildPaidTab() {
    final ColorScheme colors = Theme.of(context).colorScheme;

    if (_paid.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No paid bills yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: <Widget>[_buildSection('Paid', _paid, const Color(0xFFA7D7B5))],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final BillModel? selectedBill = _selectedBill;
    if (selectedBill != null) {
      return BillDetailsScreen(
        bill: selectedBill,
        onBack: () => setState(() => _selectedBill = null),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Bills',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Track and manage your monthly bills',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabController,
                    tabs: <Tab>[
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Text('Unpaid'),
                            if (_unpaid.isNotEmpty ||
                                _overdue.isNotEmpty) ...<Widget>[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.error.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${_unpaid.length + _overdue.length}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Text('Paid'),
                            if (_paid.isNotEmpty) ...<Widget>[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${_paid.length}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: <Widget>[_buildUnpaidTab(), _buildPaidTab()],
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute<bool>(builder: (_) => const AddBillScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
