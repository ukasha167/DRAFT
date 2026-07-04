/// A candidate returned from the metadata lookup chain.
/// Shown in the disambiguation picker — user always picks explicitly.
class BookCandidate {
  final String title;
  final String? author;
  final String? isbn;
  final String? description;

  /// Remote URL — downloaded once on confirm, then discarded. The book must
  /// be fully offline-durable immediately after the user confirms.
  final String? coverUrl;

  /// 'google_books' | 'open_library' — for debugging / provenance display.
  final String source;

  const BookCandidate({
    required this.title,
    this.author,
    this.isbn,
    this.description,
    this.coverUrl,
    required this.source,
  });

  /// Normalized title + author for the soft duplicate check.
  /// Uses the same normalization as category dedup: lowercase + trim.
  String get normalizedTitle => title.trim().toLowerCase();
  String? get normalizedAuthor => author?.trim().toLowerCase();
}

abstract class BookLookupRepository {
  /// Execute the lookup chain: Google Books → (on 429/error, one bounded
  /// retry after ~300ms) → Open Library. Returns an empty list on total
  /// failure; never throws. Falls back to an empty list so the UI can
  /// show the manual-entry form.
  Future<List<BookCandidate>> search(String query);
}
