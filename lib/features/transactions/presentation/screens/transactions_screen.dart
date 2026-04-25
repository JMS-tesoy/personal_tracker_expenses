import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/transaction.dart';
import 'add_transaction_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final supabase = Supabase.instance.client;
  List<TransactionModel> transactions = [];
  String selectedSort = 'newest';

  @override
  void initState() {
    super.initState();
    fetchTransactions();
  }

  Future<void> fetchTransactions() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month);
    final startOfNextMonth = DateTime(now.year, now.month + 1);

    final categoriesData = await supabase.from('categories').select('id, name');
    final categoryNamesById = {
      for (final category in categoriesData)
        category['id'].toString(): category['name'].toString(),
    };

    final transactionsData = await supabase
        .from('transactions')
        .select(
          'id, amount, type, category_id, payment_method, note, transaction_date, created_at',
        )
        .gte('transaction_date', databaseDate(startOfMonth))
        .lt('transaction_date', databaseDate(startOfNextMonth))
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

  String databaseDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  void sortTransactions() {
    transactions.sort((a, b) {
      switch (selectedSort) {
        case 'oldest':
          return a.createdAt.compareTo(b.createdAt);
        case 'amountHigh':
          return b.amount.compareTo(a.amount);
        case 'amountLow':
          return a.amount.compareTo(b.amount);
        case 'newest':
        default:
          return b.createdAt.compareTo(a.createdAt);
      }
    });
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
              PopupMenuItem(value: 'newest', child: Text('Newest first')),
              PopupMenuItem(value: 'oldest', child: Text('Oldest first')),
              PopupMenuItem(
                value: 'amountHigh',
                child: Text('Amount high to low'),
              ),
              PopupMenuItem(
                value: 'amountLow',
                child: Text('Amount low to high'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: transactions.isEmpty
                ? const Center(child: Text('No transactions this month'))
                : ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (context, index) {
                      final tx = transactions[index];
                      final transactionType = tx.type.toLowerCase();
                      final isIncome = transactionType == 'income';
                      final amountText =
                          '${isIncome ? '+' : '-'}${CurrencyFormatter.format(tx.amount)}';

                      return ListTile(
                        title: Text(tx.categoryName),
                        subtitle: Text(
                          '$transactionType • ${tx.paymentMethod}',
                        ),
                        trailing: Text(
                          amountText,
                          style: TextStyle(
                            color: isIncome
                                ? const Color(0xFFA7D7B5)
                                : Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    },
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
