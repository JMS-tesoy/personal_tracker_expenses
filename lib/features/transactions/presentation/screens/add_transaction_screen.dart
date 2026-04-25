import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  String type = 'expense';
  String category = 'Food';
  String paymentMethod = 'Cash';

  void saveTransaction() {
    final amount = double.tryParse(amountController.text);

    if (amount == null || amount <= 0) return;

    final newTransaction = {
      'id': const Uuid().v4(),
      'amount': amount,
      'type': type,
      'category': category,
      'paymentMethod': paymentMethod,
      'date': DateTime.now(),
      'note': noteController.text,
    };

    Navigator.pop(context, newTransaction);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount'),
            ),

            DropdownButton<String>(
              value: type,
              items: const [
                DropdownMenuItem(value: 'expense', child: Text('Expense')),
                DropdownMenuItem(value: 'income', child: Text('Income')),
              ],
              onChanged: (value) => setState(() => type = value!),
            ),

            DropdownButton<String>(
              value: category,
              items: const [
                DropdownMenuItem(value: 'Food', child: Text('Food')),
                DropdownMenuItem(value: 'Bills', child: Text('Bills')),
                DropdownMenuItem(value: 'Transport', child: Text('Transport')),
              ],
              onChanged: (value) => setState(() => category = value!),
            ),

            DropdownButton<String>(
              value: paymentMethod,
              items: const [
                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                DropdownMenuItem(value: 'Card', child: Text('Card')),
              ],
              onChanged: (value) => setState(() => paymentMethod = value!),
            ),

            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Note'),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: saveTransaction,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}