import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/auth/current_user.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../categories/domain/category.dart';
import '../../../categories/presentation/screens/categories_screen.dart';
import '../../../activity/data/repositories/activity_log_repository.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/section_header.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final supabase = Supabase.instance.client;

  final amountController = TextEditingController();
  final noteController = TextEditingController();

  String type = 'expense';
  String paymentMethod = 'Cash';
  DateTime selectedDate = DateTime.now();

  List<CategoryModel> categories = [];
  List<String> categoryTypes = ['expense', 'income'];
  String? selectedCategoryId;

  @override
  void initState() {
    super.initState();
    fetchCategoryTypes();
  }

  Future<void> fetchCategoryTypes() async {
    final String userId = requireCurrentUserId();
    final data = await supabase
        .from('categories')
        .select('type')
        .eq('user_id', userId)
        .order('type');
    final types = data
        .map<String>((item) => item['type'].toString())
        .toSet()
        .toList();

    if (!mounted) return;

    setState(() {
      categoryTypes = types.isEmpty ? ['expense', 'income'] : types;

      if (!categoryTypes.contains(type)) {
        type = categoryTypes.first;
      }
    });

    fetchCategories();
  }

  Future<void> fetchCategories() async {
    final String userId = requireCurrentUserId();
    final data = await supabase
        .from('categories')
        .select()
        .eq('type', type)
        .eq('user_id', userId)
        .order('name');

    setState(() {
      categories = data
          .map<CategoryModel>((item) => CategoryModel.fromMap(item))
          .toList();

      selectedCategoryId = categories.isNotEmpty ? categories.first.id : null;
    });
  }

  void saveTransaction() async {
    final amountText = amountController.text.trim().replaceAll(',', '');
    final amount = double.tryParse(amountText);

    if (amount == null || !amount.isFinite || amount <= 0) {
      showMessage('Enter a valid amount.');
      return;
    }

    if (amount > AppConstants.maxTransactionAmount) {
      showMessage(
        'Amount must not exceed ${CurrencyFormatter.format(AppConstants.maxTransactionAmount)}.',
      );
      return;
    }

    if (selectedCategoryId == null) {
      showMessage('Select a category first.');
      return;
    }

    CategoryModel? selectedCategory;
    for (final category in categories) {
      if (category.id == selectedCategoryId) {
        selectedCategory = category;
        break;
      }
    }

    if (selectedCategory == null) {
      showMessage('Select a valid category first.');
      return;
    }

    final transactionType = type == 'income' ? 'income' : 'expense';
    final String userId = requireCurrentUserId();
    final transactionData = {
      'user_id': userId,
      'amount': amount,
      'type': transactionType,
      'category_id': selectedCategory.id,
      'payment_method': paymentMethod,
      'transaction_date': databaseDate(selectedDate),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'is_archived': false,
      'note': noteController.text,
    };

    try {
      try {
        await supabase.from('transactions').insert(transactionData);
      } catch (e) {
        final errorText = e.toString();
        final needsLegacyCategory =
            errorText.contains('column "category"') &&
            errorText.contains('not-null constraint');

        if (!needsLegacyCategory) rethrow;

        await supabase.from('transactions').insert({
          ...transactionData,
          'category': selectedCategory.name,
        });
      }

      await ActivityLogRepository.instance.createLog(
        targetType: 'transaction',
        action: 'created',
        title: 'Transaction added',
        description: '${selectedCategory.name} $transactionType was added.',
        metadata: <String, dynamic>{
          'amount': amount,
          'type': transactionType,
          'category_name': selectedCategory.name,
          'payment_method': paymentMethod,
          'transaction_date': databaseDate(selectedDate),
        },
      );

      debugPrint('INSERT SUCCESS'); // DEBUG

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('ERROR: $e');
      if (!mounted) return;
      showMessage('Failed to save transaction: $e');
    }
  }

  Future<void> pickTransactionDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) return;
    if (!mounted) return;

    setState(() {
      selectedDate = pickedDate;
    });
  }

  Future<void> openCategoriesScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategoriesScreen()),
    );

    if (!mounted) return;
    fetchCategoryTypes();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              label: 'Amount',
            ),

            const SizedBox(height: 20),

            const SectionHeader('Type'),
            DropdownButton<String>(
              value: type,
              items: categoryTypes.map((categoryType) {
                return DropdownMenuItem(
                  value: categoryType,
                  child: Text(formatType(categoryType)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  type = value!;
                  selectedCategoryId = null;
                  categories = [];
                });

                fetchCategories();
              },
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionHeader('Category'),
                TextButton(
                  onPressed: openCategoriesScreen,
                  child: const Text('Manage'),
                ),
              ],
            ),
            DropdownButton<String>(
              value: selectedCategoryId,
              hint: const Text('Select category'),
              onTap: fetchCategories,
              items: categories.map((category) {
                return DropdownMenuItem(
                  value: category.id,
                  child: Text(category.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategoryId = value;
                });
              },
            ),

            const SizedBox(height: 20),

            const SectionHeader('Payment Method'),
            DropdownButton<String>(
              value: paymentMethod,
              items: const [
                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                DropdownMenuItem(value: 'GCash', child: Text('GCash')),
                DropdownMenuItem(value: 'Card', child: Text('Card')),
              ],
              onChanged: (value) => setState(() => paymentMethod = value!),
            ),

            const SizedBox(height: 20),

            const SectionHeader('Date'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(displayDate(selectedDate)),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: pickTransactionDate,
            ),

            const SizedBox(height: 20),

            AppTextField(controller: noteController, label: 'Note'),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: AppButton(
            label: 'Save Transaction',
            onPressed: saveTransaction,
          ),
        ),
      ),
    );
  }
}
