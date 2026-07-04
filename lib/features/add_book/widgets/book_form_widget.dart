import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/category.dart';
import '../../../shared/widgets/category_chip.dart';

/// Reusable form shared by three call sites:
///   1. Post-search confirm (prefilled from BookCandidate)
///   2. Manual entry (blank)
///   3. Edit (prefilled from existing Book)
///
/// Max 4 categories enforced live. Min 1 enforced on save.
/// Category picker is an inline expandable section — never a second sheet.
class BookFormWidget extends ConsumerStatefulWidget {
  final String? initialTitle;
  final String? initialAuthor;
  final String? initialIsbn;
  final String? initialSummary;
  final List<Category> initialCategories;
  final BookStatus initialStatus;
  final bool isEditing;

  /// Called with validated field values when the user taps Save.
  final Future<void> Function({
    required String title,
    String? author,
    String? isbn,
    String? summary,
    required List<String> categoryIds,
  }) onSave;

  const BookFormWidget({
    super.key,
    this.initialTitle,
    this.initialAuthor,
    this.initialIsbn,
    this.initialSummary,
    this.initialCategories = const [],
    this.initialStatus = BookStatus.wishlist,
    this.isEditing = false,
    required this.onSave,
  });

  @override
  ConsumerState<BookFormWidget> createState() => _BookFormWidgetState();
}

class _BookFormWidgetState extends ConsumerState<BookFormWidget> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _authorCtrl;
  late final TextEditingController _isbnCtrl;
  late final TextEditingController _summaryCtrl;
  late final TextEditingController _newCatCtrl;

  late List<Category> _selectedCategories;
  bool _showCatPicker = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle ?? '');
    _authorCtrl = TextEditingController(text: widget.initialAuthor ?? '');
    _isbnCtrl = TextEditingController(text: widget.initialIsbn ?? '');
    _summaryCtrl = TextEditingController(text: widget.initialSummary ?? '');
    _newCatCtrl = TextEditingController();
    _selectedCategories = List.of(widget.initialCategories);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _isbnCtrl.dispose();
    _summaryCtrl.dispose();
    _newCatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one category')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        title: _titleCtrl.text.trim(),
        author: _authorCtrl.text.trim().isEmpty
            ? null
            : _authorCtrl.text.trim(),
        isbn: _isbnCtrl.text.trim().isEmpty ? null : _isbnCtrl.text.trim(),
        summary: _summaryCtrl.text.trim().isEmpty
            ? null
            : _summaryCtrl.text.trim(),
        categoryIds: _selectedCategories.map((c) => c.id).toList(),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _removeCategory(Category cat) {
    setState(() => _selectedCategories.remove(cat));
  }

  void _addCategory(Category cat) {
    if (_selectedCategories.length >= 4) return; // max 4
    if (_selectedCategories.any((c) => c.id == cat.id)) return;
    setState(() => _selectedCategories.add(cat));
  }

  Future<void> _createAndAddCategory(String name) async {
    final normalized = Category.normalize(name);
    if (normalized.isEmpty) return;
    if (_selectedCategories.length >= 4) return;

    final catRepo = ref.read(categoryRepositoryProvider);
    final exists = await catRepo.isDuplicateName(normalized);
    Category cat;
    if (exists) {
      final all = await catRepo.getCategories();
      cat = all.firstWhere((c) => c.nameNormalized == normalized);
    } else {
      cat = await catRepo.createCategory(name.trim());
    }
    _addCategory(cat);
    _newCatCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        children: [
          // Title
          _Label('Title *'),
          TextFormField(
            controller: _titleCtrl,
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Title is required' : null,
            decoration: const InputDecoration(hintText: 'Book title'),
          ),
          const SizedBox(height: 16),

          // Author
          _Label('Author'),
          TextFormField(
            controller: _authorCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Author name'),
          ),
          const SizedBox(height: 16),

          // ISBN
          _Label('ISBN'),
          TextFormField(
            controller: _isbnCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '978…'),
          ),
          const SizedBox(height: 16),

          // Summary
          _Label('Summary'),
          TextFormField(
            controller: _summaryCtrl,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Brief description…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),

          // Categories
          Row(
            children: [
              const _Label('Categories'),
              const Spacer(),
              Text(
                '${_selectedCategories.length}/4',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Selected chips
          if (_selectedCategories.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _selectedCategories
                  .map((c) => CategoryChip(
                        category: c,
                        onRemove: () => _removeCategory(c),
                      ))
                  .toList(),
            ),

          // Expand category picker
          if (_selectedCategories.length < 4) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _showCatPicker = !_showCatPicker),
              icon: Icon(
                  _showCatPicker ? Icons.expand_less : Icons.add_rounded,
                  size: 18),
              label: Text(_showCatPicker ? 'Hide' : 'Add category'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
              ),
            ),
            if (_showCatPicker) _buildCategoryPicker(),
          ],

          const SizedBox(height: 28),

          // Save
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(widget.isEditing ? 'Save changes' : 'Add to library'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPicker() {
    return StreamBuilder<List<Category>>(
      stream: ref.read(categoryRepositoryProvider).watchCategories(),
      builder: (context, snap) {
        final all = snap.data ?? [];
        final available =
            all.where((c) => !_selectedCategories.any((s) => s.id == c.id));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            // Existing categories
            if (available.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: available
                    .map((c) => ActionChip(
                          label: Text(c.name),
                          onPressed: () => _addCategory(c),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 10),
            // Create new
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCatCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'New category name',
                      isDense: true,
                    ),
                    onSubmitted: _createAndAddCategory,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: () =>
                      _createAndAddCategory(_newCatCtrl.text),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
