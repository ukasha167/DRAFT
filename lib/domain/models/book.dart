import 'category.dart';

enum BookStatus { owned, wishlist }

enum ReadingStatus {
  notStarted('not_started'),
  reading('reading'),
  finished('finished');

  const ReadingStatus(this.dbValue);
  final String dbValue;

  static ReadingStatus? fromDb(String? value) => switch (value) {
        'not_started' => notStarted,
        'reading' => reading,
        'finished' => finished,
        _ => null,
      };

  String get label => switch (this) {
        notStarted => 'Not started',
        reading => 'Reading',
        finished => 'Finished',
      };
}

/// Pure domain model — no drift types, no Flutter types.
/// Mapping from drift row types happens at the repository boundary.
class Book {
  final String id;
  final String title;
  final String? author;
  final BookStatus status;

  /// Owned only — null for Wishlist books.
  final ReadingStatus? readingStatus;

  /// Owned only — false for Wishlist books.
  final bool isFavorite;

  final String? isbn;
  final String? summary;

  /// ~150px thumbnail — used in list rows (never decode full-res for a list).
  final String? coverThumbPath;

  /// Full-res — decoded only when the detail screen opens.
  final String? coverFullPath;

  /// REAL in DB — fractional/sparse positioning for Wishlist drag-reorder.
  final double sortOrder;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// Eagerly loaded — always populated at the repository boundary.
  final List<Category> categories;

  const Book({
    required this.id,
    required this.title,
    this.author,
    required this.status,
    this.readingStatus,
    this.isFavorite = false,
    this.isbn,
    this.summary,
    this.coverThumbPath,
    this.coverFullPath,
    this.sortOrder = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.categories = const [],
  });

  bool get isOwned => status == BookStatus.owned;
  bool get isWishlist => status == BookStatus.wishlist;

  /// Display initials for the cover placeholder (max 2 chars).
  String get initials {
    final words = title.trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }

  Book copyWith({
    String? id,
    String? title,
    String? author,
    BookStatus? status,
    ReadingStatus? readingStatus,
    bool? isFavorite,
    String? isbn,
    String? summary,
    String? coverThumbPath,
    String? coverFullPath,
    double? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    List<Category>? categories,
    bool clearReadingStatus = false,
    bool clearDeletedAt = false,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      status: status ?? this.status,
      readingStatus:
          clearReadingStatus ? null : (readingStatus ?? this.readingStatus),
      isFavorite: isFavorite ?? this.isFavorite,
      isbn: isbn ?? this.isbn,
      summary: summary ?? this.summary,
      coverThumbPath: coverThumbPath ?? this.coverThumbPath,
      coverFullPath: coverFullPath ?? this.coverFullPath,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      categories: categories ?? this.categories,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Book && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Book(id: $id, title: $title, status: $status)';
}
