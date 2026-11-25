import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../domain/models/category.dart';

class BookFormWidget extends ConsumerStatefulWidget {
  final String? initialTitle;
  final String? initialAuthor;
  final String? initialIsbn;
  final String? initialSummary;
  final List<Category> initialCategories;
  final bool isEditing;

  /// Puts ADD TO LIBRARY first and filled. Otherwise ADD TO WISHLIST leads.
  final bool toLibraryFirst;

  final String? initialCoverUrl;

  final ValueChanged<String>? onCoverChanged;

  final Future<void> Function({
    required String title,
    String? author,
    String? isbn,
    String? summary,
    required List<String> categoryIds,
    bool toLibrary,
  })
  onSave;

  const BookFormWidget({
    super.key,
    this.initialTitle,
    this.initialAuthor,
    this.initialIsbn,
    this.initialSummary,
    this.initialCategories = const [],
    this.isEditing = false,
    this.toLibraryFirst = false,
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
  bool _savingToLibrary = false;
  String? _localImagePath;

  static const _maxCats = 4;

  /// Built-in categories shown before "More". The rest stay one tap away.
  static const _shortList = 6;

  /// A summary longer than this starts clamped to three lines.
  static const _longSummary = 160;

  bool _allCats = false;
  late bool _summaryOpen;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle ?? '');
    _authorCtrl = TextEditingController(text: widget.initialAuthor ?? '');
    _isbnCtrl = TextEditingController(text: widget.initialIsbn ?? '');
    _summaryCtrl = TextEditingController(text: widget.initialSummary ?? '');
    _selectedIds = widget.initialCategories.map((c) => c.id).toSet();
    _summaryOpen = _summaryCtrl.text.length <= _longSummary;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _isbnCtrl.dispose();
    _summaryCtrl.dispose();
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

  Future<void> _save({bool toLibrary = false}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one category')),
      );
      return;
    }
    setState(() {
      _isSaving = true;
      _savingToLibrary = toLibrary;
    });
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
        categoryIds: _selectedIds.toList(),
        toLibrary: toLibrary,
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
    final ink = isDark ? draftInkDark : draftInk;
    final paper = isDark ? draftBackgroundDark : draftBackground;
    final cream = isDark ? draftSurfaceDark : draftSurface;

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
          // The field grows with its text, so it never scrolls inside the
          // sheet. A long summary starts at three lines; tapping opens it.
          TextFormField(
            controller: _summaryCtrl,
            minLines: 1,
            maxLines: _summaryOpen ? null : 3,
            // Collapsed, a drag on the field moves the sheet, not the text.
            scrollPhysics: _summaryOpen
                ? null
                : const NeverScrollableScrollPhysics(),
            onTap: () => setState(() => _summaryOpen = true),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Brief description…'),
          ),
          if (!_summaryOpen)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _summaryOpen = true),
                child: const Text('SHOW ALL'),
              ),
            ),
          const SizedBox(height: 20),

          Row(
            children: [
              const _Field('CATEGORIES'),
              const Spacer(),
              Text(
                '${_selectedIds.length}/$_maxCats',
                style: clashDisplayBodyMedium.copyWith(
                  color: isDark ? draftInkSecondaryDark : draftInkSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._visibleCats().map((cat) {
                final selected = _selectedIds.contains(cat.id);
                final atMax = !selected && _selectedIds.length >= _maxCats;
                return GestureDetector(
                  onTap: atMax ? null : () => _toggle(cat.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? ink : Colors.transparent,
                      border: Border.all(
                        color: atMax
                            ? (isDark ? draftDividerDark : draftDivider)
                            : selected
                            ? ink
                            : (isDark ? draftBorderDark : draftBorder),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      cat.name,
                      style: clashDisplayCaption.copyWith(
                        color: selected
                            ? paper
                            : atMax
                            ? (isDark ? draftInkDisabledDark : draftInkDisabled)
                            : (isDark
                                  ? draftInkSecondaryDark
                                  : draftInkSecondary),
                      ),
                    ),
                  ),
                );
              }),
              if (!_allCats)
                GestureDetector(
                  onTap: () => setState(() => _allCats = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? draftBorderDark : draftBorder,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'More (${kCategories.length - _visibleCats().length})',
                      style: clashDisplayCaption.copyWith(color: ink),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 28),

          // A new book picks its shelf here. Before, every new book went to
          // Wishlist, so a book added from an empty Library never showed up there.
          if (widget.isEditing)
            _button(
              label: 'SAVE CHANGES',
              filled: true,
              spinning: _isSaving,
              onPressed: () => _save(),
            )
          else ...[
            for (final toLibrary in [
              widget.toLibraryFirst,
              !widget.toLibraryFirst,
            ]) ...[
              _button(
                label: toLibrary ? 'ADD TO LIBRARY' : 'ADD TO WISHLIST',
                filled: toLibrary == widget.toLibraryFirst,
                spinning: _isSaving && _savingToLibrary == toLibrary,
                onPressed: () => _save(toLibrary: toLibrary),
              ),
              if (toLibrary == widget.toLibraryFirst) const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  /// The first six built-ins, plus any picked category outside them, so a
  /// selection never hides behind "More".
  List<Category> _visibleCats() {
    if (_allCats) return kCategories;
    return [
      for (final (i, cat) in kCategories.indexed)
        if (i < _shortList || _selectedIds.contains(cat.id)) cat,
    ];
  }

  Widget _button({
    required String label,
    required bool filled,
    required bool spinning,
    required VoidCallback onPressed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? draftInkDark : draftInk;
    final paper = isDark ? draftBackgroundDark : draftBackground;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(40),
    );
    const padding = EdgeInsets.symmetric(vertical: 20);
    final child = spinning
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: filled ? paper : ink,
            ),
          )
        : Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 0.8,
            ),
          );
    return SizedBox(
      width: double.infinity,
      child: filled
          ? FilledButton(
              onPressed: _isSaving ? null : onPressed,
              style: FilledButton.styleFrom(padding: padding, shape: shape),
              child: child,
            )
          : OutlinedButton(
              onPressed: _isSaving ? null : onPressed,
              style: OutlinedButton.styleFrom(
                padding: padding,
                shape: shape,
                foregroundColor: ink,
                side: BorderSide(
                  color: isDark ? draftBorderDark : draftBorder,
                  width: 1.5,
                ),
              ),
              child: child,
            ),
    );
  }

  Widget _buildCoverPreview(Color cream) {
    if (_localImagePath != null) {
      return Image.file(
        File(_localImagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    if (widget.initialCoverUrl != null) {
      return Image.network(
        widget.initialCoverUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _coverPlaceholder(cream),
      );
    }

    return _coverPlaceholder(cream);
  }

  Widget _coverPlaceholder(Color cream) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? draftInkDark : draftInk;
    return Container(
      color: cream,
      alignment: Alignment.center,
      child: Icon(
        Icons.menu_book_rounded,
        size: 32,
        color: ink.withOpacity(0.25),
      ),
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
      child: Text(
        text,
        style: clashDisplayLabel.copyWith(
          color: Theme.of(context).brightness == Brightness.dark
              ? draftInkSecondaryDark
              : draftInkSecondary,
        ),
      ),
    );
  }
}
