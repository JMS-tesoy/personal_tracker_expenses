import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/widgets/app_text_field.dart';
import '../../../people/domain/person.dart';

class BillFormData {
  const BillFormData({
    required this.name,
    required this.amount,
    required this.dueDay,
    required this.paymentMethod,
    this.assignedPersonId,
    this.notes,
    this.remarks,
  });

  final String name;
  final double amount;
  final int dueDay;
  final String paymentMethod;
  final String? assignedPersonId;
  final String? notes;
  final String? remarks;
}

class BillForm extends StatefulWidget {
  const BillForm({super.key, required this.onSubmit, this.isSaving = false});

  final void Function(BillFormData data) onSubmit;
  final bool isSaving;

  @override
  State<BillForm> createState() => _BillFormState();
}

class _BillFormState extends State<BillForm> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dueDayController = TextEditingController(
    text: '15',
  );
  final TextEditingController _paymentMethodController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  List<Person> _people = <Person>[];
  String? _selectedPersonId;
  bool _loadingPeople = true;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    try {
      final List<dynamic> response = await _supabase
          .from('people')
          .select()
          .order('name', ascending: true);

      if (!mounted) return;
      setState(() {
        _people = response
            .map((dynamic e) => Person.fromMap(e as Map<String, dynamic>))
            .toList();
        _loadingPeople = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPeople = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _dueDayController.dispose();
    _paymentMethodController.dispose();
    _notesController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _nameController.text.trim();
    final String amountRaw = _amountController.text.trim().replaceAll(',', '');
    final double? amount = double.tryParse(amountRaw);
    final int? dueDay = int.tryParse(_dueDayController.text.trim());
    final String paymentMethod = _paymentMethodController.text.trim();
    final String notes = _notesController.text.trim();
    final String remarks = _remarksController.text.trim();

    if (name.isEmpty) {
      _showMessage('Enter a bill name.');
      return;
    }
    if (amount == null || amount <= 0) {
      _showMessage('Enter a valid amount greater than 0.');
      return;
    }
    if (dueDay == null || dueDay < 1 || dueDay > 31) {
      _showMessage('Due day must be between 1 and 31.');
      return;
    }
    if (_selectedPersonId == null) {
      _showMessage('Please assign this bill to a person.');
      return;
    }

    widget.onSubmit(
      BillFormData(
        name: name,
        amount: amount,
        dueDay: dueDay,
        paymentMethod: paymentMethod,
        assignedPersonId: _selectedPersonId,
        notes: notes.isEmpty ? null : notes,
        remarks: remarks.isEmpty ? null : remarks,
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppTextField(label: 'Bill name', controller: _nameController),
        const SizedBox(height: 14),
        AppTextField(
          label: 'Amount',
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: 'Due day (1–31)',
          controller: _dueDayController,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: 'Payment method',
          controller: _paymentMethodController,
        ),
        const SizedBox(height: 14),
        Text(
          'Assigned to',
          style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        _loadingPeople
            ? const Center(child: CircularProgressIndicator())
            : _people.isEmpty
            ? Text(
                'No people found. Add someone in the People tab first.',
                style: TextStyle(color: colors.error),
              )
            : DropdownButtonFormField<String>(
                initialValue: _selectedPersonId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Select a person',
                ),
                items: _people
                    .map(
                      (Person p) => DropdownMenuItem<String>(
                        value: p.id,
                        child: Text(p.name),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  setState(() => _selectedPersonId = value);
                },
              ),
        const SizedBox(height: 14),
        AppTextField(
          label: 'Notes (optional)',
          controller: _notesController,
          maxLines: 2,
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: 'Remarks (optional)',
          controller: _remarksController,
          maxLines: 2,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: widget.isSaving ? null : _submit,
            child: Text(widget.isSaving ? 'Saving...' : 'Save Bill'),
          ),
        ),
      ],
    );
  }
}
