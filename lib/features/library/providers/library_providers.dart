import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/omnibox_parser.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../domain/models/book.dart';

// ---------------------------------------------------------------------------
// Tab
// ---------------------------------------------------------------------------

final currentTabProvider = StateProvider<BookStatus>((_) => BookStatus.owned);

// ---------------------------------------------------------------------------
// Filtering — text search and category tab are independent axes.
// The omnibox is gone; these replace it with simpler, direct state.
// ---------------------------------------------------------------------------

/// Raw text typed into the search field. Debounced at the call site.
final searchTextProvider = StateProvider<String>((_) => '');

/// ID of the currently selected category tab. null = "All".
final activeCategoryProvider = StateProvider<String?>((_) => null);

// ---------------------------------------------------------------------------
// Active books stream
// ---------------------------------------------------------------------------

final activeBooksProvider = StreamProvider.autoDispose<List<Book>>((ref) {
  final status    = ref.watch(currentTabProvider);
  final text      = ref.watch(searchTextProvider);
  final catId     = ref.watch(activeCategoryProvider);
  final repo      = ref.watch(bookRepositoryProvider);

  // kCategories uses id == nameNormalized for all entries, so catId works
  // directly as the slug that the repository's category filter expects.
  final query = ParsedQuery(
    text: text.trim().isEmpty ? null : text.trim(),
    categories: catId != null ? [catId] : const [],
  );

  return repo.watchBooks(status: status, query: query);
});

// ---------------------------------------------------------------------------
// Undo
// ---------------------------------------------------------------------------

final lastDeletedProvider =
    StateProvider<({String id, String title})?>((_) => null);
