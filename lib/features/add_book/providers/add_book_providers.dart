import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/book_lookup_repository.dart';

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

class AddBookForm extends AddBookState {
  final BookCandidate? prefilled;
  const AddBookForm({this.prefilled});
}

class AddBookSaving extends AddBookState {
  const AddBookSaving();
}

class AddBookDone extends AddBookState {
  const AddBookDone();
}

class AddBookNotifier extends StateNotifier<AddBookState> {
  final BookLookupRepository _lookup;

  AddBookNotifier(this._lookup) : super(const AddBookIdle());

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

  void selectCandidate(BookCandidate candidate) {
    state = AddBookForm(prefilled: candidate);
  }

  void goManual() {
    state = const AddBookForm();
  }

  void reset() {
    state = const AddBookIdle();
  }
}

final addBookProvider =
    StateNotifierProvider.autoDispose<AddBookNotifier, AddBookState>((ref) {
      return AddBookNotifier(ref.watch(bookLookupRepositoryProvider));
    });
