import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/auth/current_user.dart';
import '../../../activity/data/repositories/activity_log_repository.dart';
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
      final String userId = requireCurrentUserId();
      final String billId = const Uuid().v4();
      await _supabase.from('bills').insert(<String, dynamic>{
        'id': billId,
        'user_id': userId,
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

      await ActivityLogRepository.instance.createLog(
        targetType: 'bill',
        action: 'created',
        title: 'Bill created',
        targetId: billId,
        personId: data.assignedPersonId,
        description: '${data.name} was added.',
        metadata: <String, dynamic>{
          'bill_name': data.name,
          'amount': data.amount,
        },
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('AddBillScreen._save error: $e');
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
