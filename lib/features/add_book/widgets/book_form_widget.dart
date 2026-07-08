import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/category.dart';

/// Shared form for Add (post-search confirm), Manual Entry, and Edit.
/// Category picker uses the hardcoded [kCategories] — no dynamic CRUD.
class BookFormWidget extends ConsumerStatefulWidget {
  final String? initialTitle;
  final String? initialAuthor;
  final String? initialIsbn;
  final String? initialSummary;
  final List<Category> initialCategories;
  final bool isEditing;

  /// Remote cover URL from API search (used as fallback display).
  final String? initialCoverUrl;

  /// Called when the user picks a new local image. Receives the file path.
  final ValueChanged<String>? onCoverChanged;

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
    this.isEditing = false,
    this.initialCoverUrl,
    this.onCoverChanged,
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

  late Set<String> _selectedIds;
  bool _isSaving = false;
  String? _localImagePath; // Set when user picks a custom cover

  static const _maxCats = 4;

  @override
  void initState() {
    super.initState();
    _titleCtrl   = TextEditingController(text: widget.initialTitle ?? '');
    _authorCtrl  = TextEditingController(text: widget.initialAuthor ?? '');
    _isbnCtrl    = TextEditingController(text: widget.initialIsbn ?? '');
    _summaryCtrl = TextEditingController(text: widget.initialSummary ?? '');
    _selectedIds = widget.initialCategories.map((c) => c.id).toSet();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();  _authorCtrl.dispose();
    _isbnCtrl.dispose();   _summaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1800,
      imageQuality: 88,
    );
    if (pickedFile != null) {
      setState(() => _localImagePath = pickedFile.path);
      widget.onCoverChanged?.call(pickedFile.path);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one category')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        title: _titleCtrl.text.trim(),
        author: _authorCtrl.text.trim().isEmpty ? null : _authorCtrl.text.trim(),
        isbn: _isbnCtrl.text.trim().isEmpty ? null : _isbnCtrl.text.trim(),
        summary: _summaryCtrl.text.trim().isEmpty ? null : _summaryCtrl.text.trim(),
        categoryIds: _selectedIds.toList(),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < _maxCats) {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink    = isDark ? AppColors.dkInk : AppColors.ink;
    final paper  = isDark ? AppColors.dkPaper : AppColors.paper;
    final cream  = isDark ? AppColors.dkCream : AppColors.cream;

    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 8,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        children: [

          // ── Cover picker ────────────────────────────────────────────
          Center(
            child: GestureDetector(
              onTap: _pickCover,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 88,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: cream,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.4 : 0.10),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: _buildCoverPreview(cream),
                  ),
                  // Edit badge
                  Container(
                    margin: const EdgeInsets.all(4),
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: ink,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.edit_rounded, size: 12, color: paper),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Tap to change cover',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ink.withOpacity(0.4),
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Fields ──────────────────────────────────────────────────
          const _Field('TITLE *'),
          TextFormField(
            controller: _titleCtrl,
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Title is required' : null,
            decoration: const InputDecoration(hintText: 'Book title'),
          ),
          const SizedBox(height: 16),

          const _Field('AUTHOR'),
          TextFormField(
            controller: _authorCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Author name'),
          ),
          const SizedBox(height: 16),

          const _Field('ISBN'),
          TextFormField(
            controller: _isbnCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '978…'),
          ),
          const SizedBox(height: 16),

          const _Field('SUMMARY'),
          TextFormField(
            controller: _summaryCtrl,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Brief description…'),
          ),
          const SizedBox(height: 20),

          // ── Category picker ────────────────────────────────────────
          Row(
            children: [
              const _Field('CATEGORIES'),
              const Spacer(),
              Text(
                '${_selectedIds.length}/$_maxCats',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Wrap of toggle chips — one tap selects, another deselects.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kCategories.map((cat) {
              final selected = _selectedIds.contains(cat.id);
              final atMax =
                  !selected && _selectedIds.length >= _maxCats;
              return GestureDetector(
                onTap: atMax ? null : () => _toggle(cat.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? ink : Colors.transparent,
                    border: Border.all(
                      color: atMax
                          ? AppColors.muted.withOpacity(0.3)
                          : selected ? ink : AppColors.muted,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? paper
                          : atMax ? AppColors.muted.withOpacity(0.4)
                                  : AppColors.muted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 28),

          // Save
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40)),
              ),
              child: _isSaving
                  ? SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: paper),
                    )
                  : Text(
                      widget.isEditing ? 'SAVE CHANGES' : 'ADD TO WISHLIST',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.8,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverPreview(Color cream) {
    // 1. User picked a local file
    if (_localImagePath != null) {
      return Image.file(
        File(_localImagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    // 2. Pre-filled remote URL from API
    if (widget.initialCoverUrl != null) {
      return Image.network(
        widget.initialCoverUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _coverPlaceholder(cream),
      );
    }

    // 3. Placeholder
    return _coverPlaceholder(cream);
  }

  Widget _coverPlaceholder(Color cream) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.dkInk : AppColors.ink;
    return Container(
      color: cream,
      alignment: Alignment.center,
      child: Icon(Icons.menu_book_rounded, size: 32, color: ink.withOpacity(0.25)),
    );
  }
}

class _Field extends StatelessWidget {
  final String text;
  const _Field(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.4,
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
              )),
    );
  }
}
