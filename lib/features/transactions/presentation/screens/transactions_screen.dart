import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/auth/current_user.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../activity/data/repositories/activity_log_repository.dart';
import '../../domain/transaction.dart';
import 'add_transaction_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<TransactionModel> transactions = [];
  String selectedSort = 'descending';
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchTransactions() async {
    final String userId = requireCurrentUserId();

    final categoriesData = await supabase
        .from('categories')
        .select('id, name')
        .eq('user_id', userId);
    final categoryNamesById = {
      for (final category in categoriesData)
        category['id'].toString(): category['name'].toString(),
    };

    final transactionsData = await supabase
        .from('transactions')
        .select(
          'id, amount, type, category_id, payment_method, note, transaction_date, created_at, is_archived',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final validTransactions = transactionsData
        .map<TransactionModel?>((item) {
          final map = Map<String, dynamic>.from(item);
          final categoryName =
              categoryNamesById[map['category_id']?.toString()];
          final amount = (map['amount'] as num?)?.toDouble();

          if (categoryName == null) return null;
          if (amount == null ||
              !amount.isFinite ||
              amount <= 0 ||
              amount > AppConstants.maxTransactionAmount) {
            return null;
          }

          map['category_name'] = categoryName;
          return TransactionModel.fromMap(map);
        })
        .whereType<TransactionModel>()
        .toList();

    setState(() {
      transactions = validTransactions;
    });
  }

  void sortTransactions() {
    transactions.sort((a, b) {
      switch (selectedSort) {
        case 'ascending':
          return a.createdAt.compareTo(b.createdAt);
        case 'descending':
        default:
          return b.createdAt.compareTo(a.createdAt);
      }
    });
  }

  bool isCurrentMonth(TransactionModel transaction) {
    final DateTime now = DateTime.now();
    return transaction.transactionDate.year == now.year &&
        transaction.transactionDate.month == now.month;
  }

  List<TransactionModel> get activeTransactions {
    return transactions.where((TransactionModel tx) {
      return isCurrentMonth(tx) && !tx.isArchived;
    }).toList();
  }

  List<TransactionModel> get historyTransactions {
    return transactions.where((TransactionModel tx) {
      return !isCurrentMonth(tx) || tx.isArchived;
    }).toList();
  }

  Future<void> moveToArchive(TransactionModel transaction) async {
    try {
      await supabase
          .from('transactions')
          .update(<String, dynamic>{'is_archived': true})
          .eq('id', transaction.id)
          .eq('user_id', requireCurrentUserId());

      await ActivityLogRepository.instance.createLog(
        targetType: 'transaction',
        action: 'archived',
        title: 'Transaction archived',
        targetId: transaction.id,
        description: '${transaction.categoryName} transaction was archived.',
        metadata: <String, dynamic>{
          'amount': transaction.amount,
          'type': transaction.type,
          'category_name': transaction.categoryName,
        },
      );

      await fetchTransactions();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to move transaction to archive.')),
      );
    }
  }

  String displayDateTime(DateTime date) {
    final DateTime localDate = date.toLocal();
    final String month = localDate.month.toString().padLeft(2, '0');
    final String day = localDate.day.toString().padLeft(2, '0');
    final int hour = localDate.hour > 12
        ? localDate.hour - 12
        : localDate.hour == 0
        ? 12
        : localDate.hour;
    final String minute = localDate.minute.toString().padLeft(2, '0');
    final String period = localDate.hour >= 12 ? 'PM' : 'AM';

    return '$month/$day/${localDate.year} $hour:$minute $period';
  }

  Widget buildTransactionList(
    List<TransactionModel> items,
    String emptyMessage, {
    required bool canArchive,
  }) {
    if (items.isEmpty) {
      return Center(child: Text(emptyMessage));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final tx = items[index];
        final transactionType = tx.type.toLowerCase();
        final isIncome = transactionType == 'income';
        final amountText =
            '${isIncome ? '+' : '-'}${CurrencyFormatter.format(tx.amount)}';

        return ListTile(
          isThreeLine: true,
          title: Text(tx.categoryName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('$transactionType • ${tx.paymentMethod}'),
              const SizedBox(height: 2),
              Text(displayDateTime(tx.createdAt)),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                amountText,
                style: TextStyle(
                  color: isIncome
                      ? const Color(0xFFA7D7B5)
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (canArchive) ...<Widget>[
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (String value) {
                    if (value == 'archive') moveToArchive(tx);
                  },
                  itemBuilder: (BuildContext context) =>
                      const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'archive',
                          child: Text('Move to Archive'),
                        ),
                      ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            initialValue: selectedSort,
            onSelected: (value) {
              setState(() {
                selectedSort = value;
                sortTransactions();
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'ascending', child: Text('Ascending')),
              PopupMenuItem(value: 'descending', child: Text('Descending')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const <Tab>[
              Tab(text: 'Transaction'),
              Tab(text: 'History'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: <Widget>[
                buildTransactionList(
                  activeTransactions,
                  'No transactions this month',
                  canArchive: true,
                ),
                buildTransactionList(
                  historyTransactions,
                  'No transaction history yet',
                  canArchive: false,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
          );

          if (result == true) {
            fetchTransactions(); // reload from DB
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
