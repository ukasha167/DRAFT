/// The result of parsing an omnibox query string.
///
/// All three fields can be combined — they are ANDed together.
///
/// Examples:
///   "tolkien #fantasy :owned"  →  text="tolkien", categories=["fantasy"], viewCommand="owned"
///   "#sci-fi"                  →  text=null, categories=["sci-fi"], viewCommand=null
///   ":wishlist"                →  text=null, categories=[], viewCommand="wishlist"
///   "dune"                     →  text="dune", categories=[], viewCommand=null
class ParsedQuery {
  /// Free-text portion — run through FTS5.
  final String? text;

  /// Category slugs from `#tag` tokens (lowercased, no leading `#`).
  final List<String> categories;

  /// `:owned` or `:wishlist` view override. Null = follow the tab toggle.
  final String? viewCommand;

  const ParsedQuery({
    this.text,
    this.categories = const [],
    this.viewCommand,
  });

  bool get hasFilters =>
      (text != null && text!.isNotEmpty) ||
      categories.isNotEmpty ||
      viewCommand != null;

  bool get isEmpty => !hasFilters;

  @override
  bool operator ==(Object other) =>
      other is ParsedQuery &&
      other.text == text &&
      _listEquals(other.categories, categories) &&
      other.viewCommand == viewCommand;

  @override
  int get hashCode => Object.hash(text, Object.hashAll(categories), viewCommand);

  @override
  String toString() =>
      'ParsedQuery(text: $text, categories: $categories, view: $viewCommand)';
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Parse a raw omnibox string into its semantic components.
///
/// Rules:
///   - Tokens starting with `#` followed by at least one char → category filter.
///   - Tokens starting with `:` → view command (`owned` | `wishlist`); unknown
///     `:` tokens are treated as literal text (preserved, not silently dropped).
///   - All remaining tokens → free-text query (joined with spaces).
///   - Parsing is order-independent; tokens can appear in any order.
///
/// This is a pure function — no side effects, testable with zero setup.
ParsedQuery parseOmnibox(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return const ParsedQuery();

  final tokens = trimmed.split(RegExp(r'\s+'));
  final textParts = <String>[];
  final categories = <String>[];
  String? viewCommand;

  for (final token in tokens) {
    if (token.startsWith('#') && token.length > 1) {
      // Category token: strip leading `#`, lowercase for normalized matching.
      categories.add(token.substring(1).toLowerCase());
    } else if (token.startsWith(':') && token.length > 1) {
      final cmd = token.substring(1).toLowerCase();
      if (cmd == 'owned' || cmd == 'wishlist') {
        viewCommand = cmd; // Last one wins if multiple view commands appear.
      } else {
        textParts.add(token); // Unknown command → literal text.
      }
    } else {
      textParts.add(token);
    }
  }

  return ParsedQuery(
    text: textParts.isEmpty ? null : textParts.join(' '),
    categories: categories,
    viewCommand: viewCommand,
  );
}
