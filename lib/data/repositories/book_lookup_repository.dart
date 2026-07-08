class BookCandidate {
  final String title;
  final String? author;
  final String? isbn;
  final String? description;

  final String? coverUrl;

  final String source;

  const BookCandidate({
    required this.title,
    this.author,
    this.isbn,
    this.description,
    this.coverUrl,
    required this.source,
  });

  String get normalizedTitle => title.trim().toLowerCase();
  String? get normalizedAuthor => author?.trim().toLowerCase();
}

abstract class BookLookupRepository {
  Future<List<BookCandidate>> search(String query);
}
