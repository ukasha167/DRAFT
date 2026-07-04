import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/omnibox_parser.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/category.dart';

// ---------------------------------------------------------------------------
// Tab state
// ---------------------------------------------------------------------------

final currentTabProvider = StateProvider<BookStatus>((ref) => BookStatus.owned);

// ---------------------------------------------------------------------------
// Omnibox
// ---------------------------------------------------------------------------

final omniboxTextProvider = StateProvider<String>((ref) => '');

/// Derived: parses the raw text string into semantic components.
final parsedQueryProvider = Provider<ParsedQuery>((ref) {
  return parseOmnibox(ref.watch(omniboxTextProvider));
});

// ---------------------------------------------------------------------------
// Active books stream
// ---------------------------------------------------------------------------

final activeBooksProvider = StreamProvider.autoDispose<List<Book>>((ref) {
  var status = ref.watch(currentTabProvider);
  final query = ref.watch(parsedQueryProvider);
  final repo = ref.watch(bookRepositoryProvider);

  // :owned / :wishlist in the omnibox overrides the toggle.
  if (query.viewCommand == 'owned') status = BookStatus.owned;
  if (query.viewCommand == 'wishlist') status = BookStatus.wishlist;

  return repo.watchBooks(status: status, query: query);
});

// ---------------------------------------------------------------------------
// Undo state
// ---------------------------------------------------------------------------

final lastDeletedProvider =
    StateProvider<({String id, String title})?>((_) => null);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Strip :command tokens but keep free-text and #tags.
/// Called when the user taps the tab toggle.
String stripViewCommands(String raw) {
  return raw
      .split(RegExp(r'\s+'))
      .where((t) => t.isEmpty || !t.startsWith(':'))
      .join(' ')
      .trim();
}

/// Live stream of user-defined categories for #tag autocomplete in OmniboxField.
/// System categories (Uncategorized) excluded — they're never selectable.
final userCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchCategories();
});
