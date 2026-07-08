class ParsedQuery {
  final String? text;

  final List<String> categories;

  final String? viewCommand;

  const ParsedQuery({this.text, this.categories = const [], this.viewCommand});

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
  int get hashCode =>
      Object.hash(text, Object.hashAll(categories), viewCommand);

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

ParsedQuery parseOmnibox(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return const ParsedQuery();

  final tokens = trimmed.split(RegExp(r'\s+'));
  final textParts = <String>[];
  final categories = <String>[];
  String? viewCommand;

  for (final token in tokens) {
    if (token.startsWith('#') && token.length > 1) {
      categories.add(token.substring(1).toLowerCase());
    } else if (token.startsWith(':') && token.length > 1) {
      final cmd = token.substring(1).toLowerCase();
      if (cmd == 'owned' || cmd == 'wishlist') {
        viewCommand = cmd;
      } else {
        textParts.add(token);
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
