import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/category.dart';

/// The typed command search bar.
///
/// Displays an autocomplete dropdown when the user types `#` (categories) or
/// `:` (view commands). The dropdown appears inline below the field using a
/// simple AnimatedContainer — no Overlay complexity needed since the field
/// always sits at the top of the screen.
///
/// [onChanged] fires on every keystroke (caller debounces as needed).
class OmniboxField extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onChanged;
  final List<Category> categories; // for #tag autocomplete

  const OmniboxField({
    super.key,
    this.initialValue = '',
    required this.onChanged,
    this.categories = const [],
  });

  @override
  State<OmniboxField> createState() => _OmniboxFieldState();
}

class _OmniboxFieldState extends State<OmniboxField> {
  late final TextEditingController _ctrl;
  List<String> _suggestions = [];

  static const _viewCommands = [':owned', ':wishlist'];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue)
      ..addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(OmniboxField old) {
    super.didUpdateWidget(old);
    if (widget.initialValue != old.initialValue &&
        widget.initialValue != _ctrl.text) {
      _ctrl.text = widget.initialValue;
      _ctrl.selection =
          TextSelection.collapsed(offset: _ctrl.text.length);
    }
  }

  void _onTextChanged() {
    widget.onChanged(_ctrl.text);
    _updateSuggestions();
  }

  void _updateSuggestions() {
    final text = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) {
      setState(() => _suggestions = []);
      return;
    }

    // Find the token under the cursor.
    final before = text.substring(0, cursor);
    final tokenStart = before.lastIndexOf(RegExp(r'\s')) + 1;
    final token = before.substring(tokenStart);

    List<String> suggestions = [];
    if (token.startsWith('#')) {
      final slug = token.substring(1).toLowerCase();
      suggestions = widget.categories
          .where((c) =>
              !c.isSystem && c.nameNormalized.startsWith(slug))
          .map((c) => '#${c.name}')
          .toList();
    } else if (token.startsWith(':')) {
      final cmd = token.toLowerCase();
      suggestions =
          _viewCommands.where((c) => c.startsWith(cmd)).toList();
    }

    setState(() => _suggestions = suggestions);
  }

  void _applySuggestion(String suggestion) {
    final text = _ctrl.text;
    final cursor = _ctrl.selection.baseOffset.clamp(0, text.length);
    final before = text.substring(0, cursor);
    final tokenStart = before.lastIndexOf(RegExp(r'\s')) + 1;
    final after = text.substring(cursor);

    final newText =
        '${text.substring(0, tokenStart)}$suggestion $after'.trimRight();
    _ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
    setState(() => _suggestions = []);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _ctrl,
          textInputAction: TextInputAction.search,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Search  •  #category  •  :owned  •  :wishlist',
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.subtleDark : AppColors.subtleLight,
            ),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Clear',
                    onPressed: () {
                      _ctrl.clear();
                      setState(() => _suggestions = []);
                    },
                  )
                : null,
            filled: true,
            fillColor: fill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
        ),

        // Autocomplete dropdown
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _suggestions
                  .map((s) => InkWell(
                        onTap: () => _applySuggestion(s),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                s.startsWith('#')
                                    ? Icons.tag
                                    : Icons.filter_list,
                                size: 16,
                                color: AppColors.accent,
                              ),
                              const SizedBox(width: 10),
                              Text(s,
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.accent,
                                  )),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
