import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/bill_form.dart';

class AddBillScreen extends StatefulWidget {
  const AddBillScreen({super.key});

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isSaving = false;

  Future<void> _save(BillFormData data) async {
    setState(() => _isSaving = true);

    try {
      await _supabase.from('bills').insert(<String, dynamic>{
        'name': data.name,
        'amount': data.amount,
        'due_day': data.dueDay,
        'payment_method': data.paymentMethod,
        'assigned_person_id': data.assignedPersonId,
        'paid_by_person_id': null,
        'paid_on': null,
        'status': 'unpaid',
        'notes': data.notes,
        'remarks': data.remarks,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save bill.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Bill')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        child: BillForm(onSubmit: _save, isSaving: _isSaving),
      ),
    );
  }
}
