import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../domain/models/category.dart';

class ManageCategoriesScreen extends ConsumerStatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  ConsumerState<ManageCategoriesScreen> createState() =>
      _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState
    extends ConsumerState<ManageCategoriesScreen> {
  String? _editingId;
  late final TextEditingController _renameCtrl;
  late final TextEditingController _newCtrl;

  @override
  void initState() {
    super.initState();
    _renameCtrl = TextEditingController();
    _newCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _renameCtrl.dispose();
    _newCtrl.dispose();
    super.dispose();
  }

  Future<void> _createCategory() async {
    final name = _newCtrl.text.trim();
    if (name.isEmpty) return;
    final normalized = name.toLowerCase();
    final isDupe = await ref
        .read(categoryRepositoryProvider)
        .isDuplicateName(normalized);
    if (isDupe && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$name" already exists')),
      );
      return;
    }
    await ref.read(categoryRepositoryProvider).createCategory(name);
    _newCtrl.clear();
  }

  Future<void> _rename(String id) async {
    final newName = _renameCtrl.text.trim();
    if (newName.isEmpty) { setState(() => _editingId = null); return; }
    final normalized = newName.toLowerCase();
    final isDupe = await ref
        .read(categoryRepositoryProvider)
        .isDuplicateName(normalized, excludeId: id);
    if (isDupe && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$newName" already exists')),
      );
      return;
    }
    await ref.read(categoryRepositoryProvider).renameCategory(id, newName);
    setState(() => _editingId = null);
  }

  Future<void> _delete(Category cat) async {
    final count = await ref
        .read(categoryRepositoryProvider)
        .getBookCountForCategory(cat.id);
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${cat.name}"?'),
        content: count > 0
            ? Text(
                '$count book${count == 1 ? '' : 's'} tagged with this '
                'category will be moved to Uncategorized.',
              )
            : const Text('This category will be permanently deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(categoryRepositoryProvider).deleteCategory(cat.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage categories')),
      body: Column(
        children: [
          // Add new
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'New category name',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _createCategory(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: _createCategory,
                  tooltip: 'Create category',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // List
          Expanded(
            child: StreamBuilder<List<Category>>(
              stream: ref
                  .read(categoryRepositoryProvider)
                  .watchCategories(),
              builder: (context, snap) {
                final cats = snap.data ?? [];
                if (cats.isEmpty) {
                  return const Center(
                      child: Text('No categories yet'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: cats.length,
                  itemBuilder: (context, i) {
                    final cat = cats[i];
                    final isEditing = _editingId == cat.id;

                    if (isEditing) {
                      return ListTile(
                        title: TextField(
                          controller: _renameCtrl,
                          autofocus: true,
                          decoration: const InputDecoration(isDense: true),
                          onSubmitted: (_) => _rename(cat.id),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_rounded,
                                  color: AppColors.success),
                              onPressed: () => _rename(cat.id),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () =>
                                  setState(() => _editingId = null),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListTile(
                      title: Text(cat.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 20),
                            tooltip: 'Rename',
                            onPressed: () {
                              _renameCtrl.text = cat.name;
                              setState(() => _editingId = cat.id);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 20, color: AppColors.error),
                            tooltip: 'Delete',
                            onPressed: () => _delete(cat),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
