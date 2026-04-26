import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/current_user.dart';
import '../widgets/person_form.dart';

class AddPersonScreen extends StatefulWidget {
  const AddPersonScreen({super.key, this.initialRole});

  final String? initialRole;

  @override
  State<AddPersonScreen> createState() => _AddPersonScreenState();
}

class _AddPersonScreenState extends State<AddPersonScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isSaving = false;

  Future<void> _save(PersonFormData data) async {
    setState(() => _isSaving = true);

    try {
      final String userId = requireCurrentUserId();
      final bool nameExists = await _personNameExists(userId, data.name);
      if (!mounted) return;
      if (nameExists) {
        setState(() => _isSaving = false);
        _showMessage('A person with this name already exists.');
        return;
      }

      await _supabase.from('people').insert(<String, dynamic>{
        'user_id': userId,
        'name': data.name,
        'role': data.role,
      });

      if (!mounted) return;
      Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (error.code == '23505') {
        _showMessage('A person with this name already exists.');
        return;
      }
      _showMessage('Error saving person: ${error.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('Error saving person: $e');
    }
  }

  Future<bool> _personNameExists(String userId, String name) async {
    final String targetName = _normalizeName(name);
    final List<dynamic> rows = await _supabase
        .from('people')
        .select('name')
        .eq('user_id', userId);

    return rows.any((dynamic row) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(row as Map);
      return _normalizeName(map['name']?.toString() ?? '') == targetName;
    });
  }

  String _normalizeName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Person')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        child: PersonForm(
          onSubmit: _save,
          isSaving: _isSaving,
          initialRole: widget.initialRole,
        ),
      ),
    );
  }
}
