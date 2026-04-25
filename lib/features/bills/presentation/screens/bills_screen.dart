import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/bill.dart';
import '../widgets/bill_card.dart';
import 'add_bill_screen.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  late final StreamSubscription<List<Map<String, dynamic>>> _subscription;

  bool isLoading = true;
  List<BillModel> _unpaid = <BillModel>[];
  List<BillModel> _overdue = <BillModel>[];
  List<BillModel> _paid = <BillModel>[];

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _subscribe() {
    _subscription = supabase
        .from('bills')
        .stream(primaryKey: <String>['id'])
        .order('due_day', ascending: true)
        .listen(
          (List<Map<String, dynamic>> data) {
            if (!mounted) return;
            final List<BillModel> all = data.map(BillModel.fromMap).toList();
            setState(() {
              _unpaid =
                  all.where((BillModel b) => b.isUnpaid).toList();
              _overdue =
                  all.where((BillModel b) => b.isOverdue).toList();
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
      await supabase
          .from('bills')
          .update(<String, dynamic>{
            'status': 'paid',
            'paid_on': today,
          })
          .eq('id', bill.id);
    } catch (_) {
      _showMessage('Failed to mark bill as paid.');
    }
  }

  Future<void> _markUnpaid(BillModel bill) async {
    try {
      await supabase
          .from('bills')
          .update(<String, dynamic>{
            'status': 'unpaid',
            'paid_on': null,
          })
          .eq('id', bill.id);
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
      await supabase.from('bills').delete().eq('id', bill.id);
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
            onMarkPaid: () => _markPaid(bill),
            onMarkUnpaid: () => _markUnpaid(bill),
            onDelete: () => _confirmDelete(bill),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.receipt_long_outlined,
            size: 56,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No bills yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + to add your first bill.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool allEmpty =
        _unpaid.isEmpty && _overdue.isEmpty && _paid.isEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : allEmpty
            ? _buildEmptyState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: <Widget>[
                  Text(
                    'Bills',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track and manage your monthly bills',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSection('Overdue', _overdue, colorScheme.error),
                  _buildSection('Unpaid', _unpaid, colorScheme.primary),
                  _buildSection(
                    'Paid',
                    _paid,
                    const Color(0xFFA7D7B5),
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