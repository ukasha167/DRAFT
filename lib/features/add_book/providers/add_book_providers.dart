import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/book_lookup_repository.dart';

// ---------------------------------------------------------------------------
// State model — sealed classes (Dart 3+)
// ---------------------------------------------------------------------------

sealed class AddBookState {
  const AddBookState();
}

class AddBookIdle extends AddBookState {
  const AddBookIdle();
}

class AddBookSearching extends AddBookState {
  final String query;
  const AddBookSearching(this.query);
}

class AddBookResults extends AddBookState {
  final List<BookCandidate> candidates;
  final String query;
  const AddBookResults(this.candidates, this.query);
}

class AddBookNoResults extends AddBookState {
  const AddBookNoResults();
}

class AddBookError extends AddBookState {
  final String message;
  const AddBookError(this.message);
}

/// Disambiguation chosen or "enter manually" selected — show the form.
class AddBookForm extends AddBookState {
  /// null = manual entry (no pre-fill).
  final BookCandidate? prefilled;
  const AddBookForm({this.prefilled});
}

class AddBookSaving extends AddBookState {
  const AddBookSaving();
}

class AddBookDone extends AddBookState {
  const AddBookDone();
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class AddBookNotifier extends StateNotifier<AddBookState> {
  final BookLookupRepository _lookup;

  AddBookNotifier(this._lookup) : super(const AddBookIdle());

  /// Triggered by the debounced omnibox in AddBookSheet.
  /// Caller is responsible for debouncing and the 3-char minimum.
  Future<void> search(String query) async {
    if (query.trim().length < 3) {
      state = const AddBookIdle();
      return;
    }
    state = AddBookSearching(query);
    try {
      final results = await _lookup.search(query);
      if (!mounted) return;
      state = results.isEmpty
          ? const AddBookNoResults()
          : AddBookResults(results, query);
    } catch (_) {
      if (mounted) state = const AddBookError('Search failed');
    }
  }

  /// User picked a candidate from the disambiguation list.
  void selectCandidate(BookCandidate candidate) {
    state = AddBookForm(prefilled: candidate);
  }

  /// User chose "enter manually" — blank form.
  void goManual() {
    state = const AddBookForm();
  }

  void reset() {
    state = const AddBookIdle();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final addBookProvider =
    StateNotifierProvider.autoDispose<AddBookNotifier, AddBookState>((ref) {
  return AddBookNotifier(ref.watch(bookLookupRepositoryProvider));
});
