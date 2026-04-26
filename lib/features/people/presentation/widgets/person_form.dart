import 'package:flutter/material.dart';

import '../../domain/person_avatar.dart';

class PersonFormData {
  const PersonFormData({required this.name, this.role, this.avatarUrl});

  final String name;
  final String? role;
  final String? avatarUrl;
}

class PersonForm extends StatefulWidget {
  const PersonForm({
    super.key,
    required this.onSubmit,
    this.isSaving = false,
    this.initialRole,
  });

  final void Function(PersonFormData data) onSubmit;
  final bool isSaving;
  final String? initialRole;

  @override
  State<PersonForm> createState() => _PersonFormState();
}

class _PersonFormState extends State<PersonForm> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  String? _selectedAvatarId;

  @override
  void initState() {
    super.initState();
    _roleController.text = widget.initialRole ?? '';
  }

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
      PersonFormData(
        name: name,
        role: role.isEmpty ? null : role,
        avatarUrl: _selectedAvatarId,
      ),
    );
  }

  Future<void> _chooseAvatar() async {
    final String? selectedId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Choose Avatar',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 14),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: personAvatars.length,
                  itemBuilder: (BuildContext context, int index) {
                    final PersonAvatar avatar = personAvatars[index];
                    final bool isSelected = avatar.id == _selectedAvatarId;

                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => Navigator.of(sheetContext).pop(avatar.id),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: avatar.backgroundColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected
                                ? avatar.foregroundColor
                                : avatar.backgroundColor,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          avatar.icon,
                          color: avatar.foregroundColor,
                          size: 30,
                        ),
                      ),
                    );
                  },
                ),
                if (_selectedAvatarId != null) ...<Widget>[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(sheetContext).pop(''),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove avatar'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selectedId == null) return;
    setState(() {
      _selectedAvatarId = selectedId.isEmpty ? null : selectedId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final PersonAvatar? selectedAvatar = personAvatarById(_selectedAvatarId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Center(
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _chooseAvatar,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                CircleAvatar(
                  radius: 40,
                  backgroundColor: selectedAvatar?.backgroundColor ??
                      colors.primaryContainer,
                  child: Icon(
                    selectedAvatar?.icon ?? Icons.person,
                    size: 40,
                    color: selectedAvatar?.foregroundColor ??
                        colors.onPrimaryContainer,
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surface, width: 2),
                    ),
                    child: Icon(
                      Icons.add,
                      size: 18,
                      color: colors.onPrimary,
                    ),
                  ),
                ),
              ],
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
