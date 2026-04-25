import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/category.dart';

class CategoryFormResult {
  const CategoryFormResult({required this.name, required this.type});

  final String name;
  final String type;
}

class CategoryFormDialog extends StatefulWidget {
  const CategoryFormDialog({
    super.key,
    this.category,
    this.existingTypes = const [],
  });

  final CategoryModel? category;
  final List<String> existingTypes;

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  static const customTypeValue = '__custom_type__';

  late final TextEditingController nameController;
  late final TextEditingController typeController;
  late String selectedType;
  late String type;

  bool get isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.category?.name ?? '');
    type = widget.category?.type ?? '';
    selectedType = type.isEmpty
        ? availableTypes.first
        : type.trim().toLowerCase();
    typeController = TextEditingController();
  }

  @override
  void dispose() {
    nameController.dispose();
    typeController.dispose();
    super.dispose();
  }

  void submit() {
    final name = nameController.text.trim();
    String selectedType;

    if (this.selectedType == customTypeValue) {
      selectedType = typeController.text.trim().toLowerCase();
    } else {
      selectedType = this.selectedType;
    }

    if (name.isEmpty || selectedType.isEmpty) return;

    Navigator.pop(context, CategoryFormResult(name: name, type: selectedType));
  }

  String formatType(String value) {
    if (value.isEmpty) return value;

    return value[0].toUpperCase() + value.substring(1);
  }

  List<String> get availableTypes {
    final seenTypes = <String>{};
    final types = <String>[];

    void addType(String item) {
      final normalizedType = item.trim().toLowerCase();

      if (normalizedType.isEmpty || seenTypes.contains(normalizedType)) {
        return;
      }

      seenTypes.add(normalizedType);
      types.add(normalizedType);
    }

    addType(type);

    for (final item in widget.existingTypes) {
      addType(item);
    }

    return types.isEmpty ? ['expense', 'income'] : types;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(isEditing ? 'Edit Category' : 'Add Category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(controller: nameController, label: 'Category name'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: [
                ...availableTypes.map((categoryType) {
                  return DropdownMenuItem(
                    value: categoryType,
                    child: Text(formatType(categoryType)),
                  );
                }),
                const DropdownMenuItem(
                  value: customTypeValue,
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 18),
                      SizedBox(width: 8),
                      Text('New type'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  selectedType = value;
                });
              },
            ),
            if (selectedType == customTypeValue) ...[
              const SizedBox(height: 16),
              AppTextField(controller: typeController, label: 'New type'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: submit,
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
