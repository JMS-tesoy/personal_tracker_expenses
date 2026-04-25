import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/category.dart';
import '../widgets/category_form_dialog.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final supabase = Supabase.instance.client;
  List<CategoryModel> categories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    try {
      final data = await supabase
          .from('categories')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        categories = List<Map<String, dynamic>>.from(
          data,
        ).map(CategoryModel.fromMap).toList();
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      showMessage('Failed to load categories.');
    }
  }

  Future<void> addCategory() async {
    final result = await showDialog<CategoryFormResult>(
      context: context,
      builder: (context) => CategoryFormDialog(existingTypes: categoryTypes()),
    );

    if (result == null) return;

    if (await categoryExists(name: result.name, type: result.type)) {
      showMessage('Category already exists.');
      return;
    }

    try {
      await supabase.from('categories').insert({
        'name': result.name,
        'type': result.type,
      });

      await fetchCategories();
      showMessage('Category added.');
    } catch (e) {
      showMessage('Failed to add category: $e');
    }
  }

  Future<void> editCategory(CategoryModel category) async {
    final result = await showDialog<CategoryFormResult>(
      context: context,
      builder: (context) => CategoryFormDialog(
        category: category,
        existingTypes: categoryTypes(),
      ),
    );

    if (result == null) return;

    if (await categoryExists(
      name: result.name,
      type: result.type,
      excludeId: category.id,
    )) {
      showMessage('Category already exists.');
      return;
    }

    try {
      await supabase
          .from('categories')
          .update({'name': result.name, 'type': result.type})
          .eq('id', category.id);

      await fetchCategories();
      showMessage('Category updated.');
    } catch (e) {
      showMessage('Failed to update category.');
    }
  }

  Future<void> confirmDeleteCategory(CategoryModel category) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete category?'),
          content: Text('Delete "${category.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await supabase.from('categories').delete().eq('id', category.id);

      await fetchCategories();
      showMessage('Category deleted.');
    } catch (e) {
      showMessage('Failed to delete category.');
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<CategoryModel> categoriesByType(String type) {
    return categories.where((category) => category.type == type).toList();
  }

  List<String> categoryTypes() {
    final types = categories.map((category) => category.type).toSet().toList();

    if (types.isEmpty) return ['expense', 'income'];

    types.sort((a, b) {
      const priority = {
        'expense': 0,
        'income': 1,
        'savings': 2,
        'plan': 3,
        'investment': 4,
        'debt': 5,
      };
      final aPriority = priority[a] ?? 99;
      final bPriority = priority[b] ?? 99;

      if (aPriority != bPriority) return aPriority.compareTo(bPriority);

      return a.compareTo(b);
    });

    return types;
  }

  String formatType(String value) {
    if (value.isEmpty) return value;

    return value[0].toUpperCase() + value.substring(1);
  }

  Color typeColor(String type) {
    switch (type) {
      case 'expense':
        return const Color(0xFFD8DCE1);
      case 'income':
        return const Color(0xFFB8C0CA);
      case 'savings':
        return const Color(0xFFC9CED6);
      case 'plan':
        return const Color(0xFFAEB7C2);
      case 'investment':
        return const Color(0xFFDDE0E4);
      case 'debt':
        return const Color(0xFFBFC6CF);
      default:
        return const Color(0xFFC5CCD5);
    }
  }

  IconData typeIcon(String type) {
    switch (type) {
      case 'expense':
        return Icons.payments_outlined;
      case 'income':
        return Icons.savings_outlined;
      case 'savings':
        return Icons.account_balance_wallet_outlined;
      case 'plan':
        return Icons.flag_outlined;
      case 'investment':
        return Icons.trending_up_outlined;
      case 'debt':
        return Icons.credit_card_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  Future<bool> categoryExists({
    required String name,
    required String type,
    String? excludeId,
  }) async {
    final normalizedName = name.trim().toLowerCase();

    if (categories.any((category) {
      if (excludeId != null && category.id == excludeId) return false;

      return category.type == type &&
          category.name.trim().toLowerCase() == normalizedName;
    })) {
      return true;
    }

    final data = await supabase
        .from('categories')
        .select('id, name, type')
        .eq('type', type);

    return List<Map<String, dynamic>>.from(data).any((category) {
      if (excludeId != null && category['id'].toString() == excludeId) {
        return false;
      }

      return category['name'].toString().trim().toLowerCase() == normalizedName;
    });
  }

  Widget buildAnimatedEntrance({required Widget child, required int index}) {
    final extraDuration = (index * 35).clamp(0, 210).toInt();

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + extraDuration),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }

  Widget buildOverviewCard() {
    final types = categoryTypes();

    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: buildOverviewItem(
                icon: Icons.category_outlined,
                label: 'Categories',
                value: categories.length.toString(),
              ),
            ),
            Container(
              width: 1,
              height: 46,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(
              child: buildOverviewItem(
                icon: Icons.auto_awesome_mosaic_outlined,
                label: 'Types',
                value: types.length.toString(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildOverviewItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.category_outlined,
                size: 36,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No categories yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCategorySection(String type, List<CategoryModel> items) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = typeColor(type);
    final title = formatType(type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(typeIcon(type), color: accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.65,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                items.length.toString(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'No ${title.toLowerCase()} categories yet',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          ...items.asMap().entries.map(
            (entry) => buildAnimatedEntrance(
              index: entry.key,
              child: buildCategoryTile(entry.value, accentColor),
            ),
          ),
      ],
    );
  }

  Widget buildCategoryTile(CategoryModel category, Color accentColor) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: ListTile(
        minVerticalPadding: 14,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.label_outline, color: accentColor),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(formatType(category.type)),
        trailing: Wrap(
          spacing: 2,
          children: [
            IconButton(
              tooltip: 'Edit',
              onPressed: () => editCategory(category),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete',
              onPressed: () => confirmDeleteCategory(category),
              icon: Icon(Icons.delete_outline, color: colorScheme.error),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: isLoading
            ? const Center(
                key: ValueKey('loading'),
                child: CircularProgressIndicator(),
              )
            : RefreshIndicator(
                key: const ValueKey('categories'),
                onRefresh: fetchCategories,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    if (categories.isEmpty)
                      buildEmptyState()
                    else ...[
                      buildAnimatedEntrance(
                        index: 0,
                        child: buildOverviewCard(),
                      ),
                      const SizedBox(height: 24),
                      ...categoryTypes().asMap().entries.map(
                        (entry) => buildAnimatedEntrance(
                          index: entry.key + 1,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 26),
                            child: buildCategorySection(
                              entry.value,
                              categoriesByType(entry.value),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addCategory,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }
}
