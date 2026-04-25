import 'package:flutter/material.dart';

class PersonFormData {
  const PersonFormData({required this.name, this.role});

  final String name;
  final String? role;
}

class PersonForm extends StatefulWidget {
  const PersonForm({super.key, required this.onSubmit, this.isSaving = false});

  final void Function(PersonFormData data) onSubmit;
  final bool isSaving;

  @override
  State<PersonForm> createState() => _PersonFormState();
}

class _PersonFormState extends State<PersonForm> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _nameController.text.trim();
    final String role = _roleController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Name is required.')));
      return;
    }

    widget.onSubmit(
      PersonFormData(name: name, role: role.isEmpty ? null : role),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Avatar placeholder
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: colors.primaryContainer,
            child: Icon(
              Icons.person,
              size: 40,
              color: colors.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _roleController,
          decoration: const InputDecoration(
            labelText: 'Role (optional)',
            hintText: 'e.g. owner, member',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: widget.isSaving ? null : _submit,
            child: Text(widget.isSaving ? 'Saving...' : 'Save Person'),
          ),
        ),
      ],
    );
  }
}
