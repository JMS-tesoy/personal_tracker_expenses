import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/section_header.dart';

class AddLoanScreen extends StatefulWidget {
  const AddLoanScreen({super.key});

  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController lenderController = TextEditingController();
  final TextEditingController originalAmountController =
      TextEditingController();
  final TextEditingController totalCyclesController = TextEditingController(
    text: '1',
  );
  final TextEditingController dueDayController = TextEditingController(
    text: '15',
  );
  final TextEditingController notesController = TextEditingController();

  late DateTime selectedStartDate;
  late DateTime selectedNextDueDate;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final DateTime today = DateTime.now();
    selectedStartDate = DateTime(today.year, today.month, today.day);
    selectedNextDueDate = _nextDueDateFromDay(15);
    originalAmountController.addListener(_refreshPreview);
    totalCyclesController.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    nameController.dispose();
    lenderController.dispose();
    originalAmountController
      ..removeListener(_refreshPreview)
      ..dispose();
    totalCyclesController
      ..removeListener(_refreshPreview)
      ..dispose();
    dueDayController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _refreshPreview() => setState(() {});

  double? _parseMoney(String value) {
    final String cleaned = value.trim().replaceAll(',', '');
    return double.tryParse(cleaned);
  }

  double get _computedMonthlyInstallment {
    final double? amount = _parseMoney(originalAmountController.text);
    final int? cycles = int.tryParse(totalCyclesController.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0) return 0;
    if (cycles == null || cycles < 1) return 0;
    return amount / cycles;
  }

  double get _previewPerPayday => _computedMonthlyInstallment / 2;

  DateTime _nextDueDateFromDay(int dueDay) {
    final DateTime today = DateTime.now();
    final DateTime thisMonth = _dueDateForMonth(
      today.year,
      today.month,
      dueDay,
    );
    if (!thisMonth.isBefore(DateTime(today.year, today.month, today.day))) {
      return thisMonth;
    }
    return _dueDateForMonth(today.year, today.month + 1, dueDay);
  }

  DateTime _dueDateForMonth(int year, int month, int dueDay) {
    final int lastDay = DateTime(year, month + 1, 0).day;
    final int safeDay = dueDay.clamp(1, lastDay);
    return DateTime(year, month, safeDay);
  }

  Future<void> _pickStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedStartDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      selectedStartDate = picked;
      if (selectedNextDueDate.isBefore(selectedStartDate)) {
        selectedNextDueDate = selectedStartDate;
      }
    });
  }

  Future<void> _pickNextDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedNextDueDate,
      firstDate: selectedStartDate,
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => selectedNextDueDate = picked);
  }

  Future<void> _saveLoan() async {
    final String name = nameController.text.trim();
    final String lender = lenderController.text.trim();
    final String notes = notesController.text.trim();
    final double? originalAmount = _parseMoney(originalAmountController.text);
    final int? totalCycles = int.tryParse(totalCyclesController.text.trim());
    final int? dueDay = int.tryParse(dueDayController.text.trim());
    final double monthlyInstallment = _computedMonthlyInstallment;

    if (name.isEmpty) {
      _showMessage('Enter a loan name.');
      return;
    }
    if (originalAmount == null ||
        !originalAmount.isFinite ||
        originalAmount <= 0) {
      _showMessage('Enter a valid original amount.');
      return;
    }
    if (totalCycles == null || totalCycles < 1) {
      _showMessage('Total cycles must be at least 1.');
      return;
    }
    if (monthlyInstallment <= 0) {
      _showMessage('Monthly installment could not be calculated.');
      return;
    }
    if (dueDay == null || dueDay < 1 || dueDay > 31) {
      _showMessage('Due day must be from 1 to 31.');
      return;
    }
    if (selectedNextDueDate.isBefore(selectedStartDate)) {
      _showMessage('Next due date cannot be before start date.');
      return;
    }

    final int totalPaydays = totalCycles * 2;

    setState(() => isSaving = true);

    try {
      await supabase.from('loans').insert(<String, dynamic>{
        'name': name,
        'lender': lender.isEmpty ? null : lender,
        'original_amount': originalAmount,
        'remaining_balance': originalAmount,
        'monthly_installment': monthlyInstallment,
        'total_cycles': totalCycles,
        'paid_cycles': 0,
        'total_paydays': totalPaydays,
        'paid_paydays': 0,
        'start_date': _toDbDate(selectedStartDate),
        'next_due_date': _toDbDate(selectedNextDueDate),
        'due_day': dueDay,
        'status': 'active',
        'notes': notes.isEmpty ? null : notes,
      });

      if (!mounted) return;
      setState(() => isSaving = false);
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Failed to save loan. Run the Supabase loans SQL first.');
      setState(() => isSaving = false);
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
    final String installmentText = _computedMonthlyInstallment > 0
        ? CurrencyFormatter.format(_computedMonthlyInstallment)
        : '';

    return Scaffold(
      appBar: AppBar(title: const Text('Add Loan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AppTextField(label: 'Loan name', controller: nameController),
            const SizedBox(height: 14),
            AppTextField(label: 'Lender', controller: lenderController),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Original amount',
              controller: originalAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 14),

            // ── Read-only: auto-calculated monthly installment ───────────
            TextField(
              controller: TextEditingController(text: installmentText),
              readOnly: true,
              keyboardType: TextInputType.none,
              decoration: InputDecoration(
                labelText: 'Monthly installment (auto-calculated)',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.40,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),

            // ─────────────────────────────────────────────────────────────
            const SizedBox(height: 14),
            AppTextField(
              label: 'Total cycles (months)',
              controller: totalCyclesController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Due day',
              controller: dueDayController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            const SectionHeader('Loan Dates'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_displayDate(selectedStartDate)),
              subtitle: const Text('Start date'),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: _pickStartDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_displayDate(selectedNextDueDate)),
              subtitle: const Text('Next due date'),
              trailing: const Icon(Icons.event_available_outlined),
              onTap: _pickNextDueDate,
            ),
            const SizedBox(height: 20),
            const SectionHeader('Payday allocation'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.72,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.86),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.payments_outlined, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      CurrencyFormatter.format(_previewPerPayday),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '15th and 30th',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: 'Notes',
              controller: notesController,
              maxLines: 3,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: AppButton(
            label: isSaving ? 'Saving...' : 'Save Loan',
            onPressed: isSaving ? null : _saveLoan,
          ),
        ),
      ),
    );
  }
}
