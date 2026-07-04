import 'package:drift/drift.dart';
import '../database.dart';

part 'books_dao.g.dart';

@DriftAccessor(tables: [Books, Categories, BookCategories])
class BooksDao extends DatabaseAccessor<AppDatabase> with _$BooksDaoMixin {
  BooksDao(super.db);

  // ---------------------------------------------------------------------------
  // Reactive streams
  // ---------------------------------------------------------------------------

  /// Owned books, newest first. Stream also fires on book_categories changes
  /// (category assignment, rename) because of the JOIN in readsFrom.
  Stream<List<BookRow>> watchOwned() {
    return customSelect(
      'SELECT DISTINCT b.* FROM books b '
      'LEFT JOIN book_categories bc ON b.id = bc.book_id '
      'WHERE b.status = ? AND b.deleted_at IS NULL '
      'ORDER BY b.created_at DESC',
      variables: [const Variable('owned')],
      readsFrom: {books, bookCategories, categories},
    ).watch().map((rows) => rows.map(_mapQueryRow).toList());
  }

  /// Wishlist books, sort_order ASC (manual drag order).
  Stream<List<BookRow>> watchWishlist() {
    return customSelect(
      'SELECT DISTINCT b.* FROM books b '
      'LEFT JOIN book_categories bc ON b.id = bc.book_id '
      'WHERE b.status = ? AND b.deleted_at IS NULL '
      'ORDER BY b.sort_order ASC',
      variables: [const Variable('wishlist')],
      readsFrom: {books, bookCategories, categories},
    ).watch().map((rows) => rows.map(_mapQueryRow).toList());
  }

  /// Single book stream — used by the detail screen for live updates.
  Stream<BookRow?> watchById(String id) {
    return (select(books)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  // ---------------------------------------------------------------------------
  // Futures
  // ---------------------------------------------------------------------------

  Future<BookRow?> getById(String id) {
    return (select(books)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Full-text search via FTS5. Prefix-matches on title / author / summary.
  /// NEVER use LIKE '%query%' — this is the correct path.
  /// Caller must not pass empty string; checked before calling.
  Future<List<BookRow>> fullTextSearch(String rawQuery) async {
    // Escape embedded double-quotes and wrap for prefix search.
    final escaped = rawQuery.trim().replaceAll('"', '""');
    final ftsQuery = '"$escaped"*';

    final rows = await customSelect(
      'SELECT b.* FROM books b '
      'JOIN books_fts ON b.rowid = books_fts.rowid '
      'WHERE books_fts MATCH ? AND b.deleted_at IS NULL '
      'ORDER BY books_fts.rank',
      variables: [Variable.withString(ftsQuery)],
      readsFrom: {books},
    ).get();

    return rows.map(_mapQueryRow).toList();
  }

  /// Rows whose deleted_at is older than [cutoffMs] — fetched for the
  /// post-first-frame sweep (file cleanup + hard delete).
  Future<List<BookRow>> getExpired(int cutoffMs) {
    return customSelect(
      'SELECT * FROM books WHERE deleted_at IS NOT NULL AND deleted_at < ?',
      variables: [Variable(cutoffMs)],
      readsFrom: {books},
    ).map(_mapQueryRow).get();
  }

  /// Max sort_order among active wishlist books; 0 if empty.
  /// Used to append a new book to the end of the list.
  Future<double> getMaxWishlistSortOrder() async {
    final row = await customSelect(
      "SELECT MAX(sort_order) AS m FROM books "
      "WHERE status = 'wishlist' AND deleted_at IS NULL",
      readsFrom: {books},
    ).getSingleOrNull();
    return row?.readNullable<double>('m') ?? 0.0;
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  Future<void> insertBook(BooksCompanion book) => into(books).insert(book);

  Future<void> updateBook(BooksCompanion patch, String id) {
    return (update(books)..where((t) => t.id.equals(id))).write(patch);
  }

  /// Soft delete: set deleted_at = now. The UI shows an undo snackbar;
  /// rows are swept ~60 s later by sweepExpiredDeletes().
  Future<void> softDelete(String id, int nowMs) {
    return (update(books)..where((t) => t.id.equals(id))).write(
      BooksCompanion(
        deletedAt: Value(nowMs),
        updatedAt: Value(nowMs),
      ),
    );
  }

  /// Undo: clear deleted_at.
  Future<void> restore(String id, int nowMs) {
    return (update(books)..where((t) => t.id.equals(id))).write(
      BooksCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(nowMs),
      ),
    );
  }

  /// Hard delete called after TTL expires or undo window closes.
  Future<void> hardDelete(String id) {
    return (delete(books)..where((t) => t.id.equals(id))).go();
  }

  /// Update sort_order for one row — the only row touched during a drag.
  Future<void> updateSortOrder(String id, double newOrder, int nowMs) {
    return (update(books)..where((t) => t.id.equals(id))).write(
      BooksCompanion(
        sortOrder: Value(newOrder),
        updatedAt: Value(nowMs),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  BookRow _mapQueryRow(QueryRow row) => BookRow(
        id: row.read<String>('id'),
        title: row.read<String>('title'),
        author: row.readNullable<String>('author'),
        status: row.read<String>('status'),
        readingStatus: row.readNullable<String>('reading_status'),
        isFavorite: row.read<int>('is_favorite'),
        isbn: row.readNullable<String>('isbn'),
        summary: row.readNullable<String>('summary'),
        coverThumbPath: row.readNullable<String>('cover_thumb_path'),
        coverFullPath: row.readNullable<String>('cover_full_path'),
        sortOrder: row.read<double>('sort_order'),
        createdAt: row.read<int>('created_at'),
        updatedAt: row.read<int>('updated_at'),
        deletedAt: row.readNullable<int>('deleted_at'),
      );
}
