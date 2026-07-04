import '../../domain/models/book.dart';
import '../../core/utils/omnibox_parser.dart';

/// Abstract repository interface — the seam where a cloud-backed implementation
/// replaces this local one without touching any widget or provider.
abstract class BookRepository {
  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Reactive stream of books filtered by [status] and the parsed omnibox
  /// [query]. All conditions are ANDed: free-text (FTS5), #category filter,
  /// and :view command (which overrides the tab from above).
  Stream<List<Book>> watchBooks({
    required BookStatus status,
    ParsedQuery? query,
  });

  /// Single-book reactive stream — used by the detail screen.
  Stream<Book?> watchBook(String id);

  Future<Book?> getBook(String id);

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  /// Insert a new book. [coverUrl] is downloaded, resized, and stored locally
  /// before this future resolves; the remote URL is discarded afterward.
  Future<void> addBook({
    required String title,
    required BookStatus status,
    String? author,
    String? isbn,
    String? summary,
    String? coverUrl,
    required List<String> categoryIds,
  });

  // ---------------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------------

  Future<void> updateBook({
    required String id,
    required String title,
    String? author,
    String? isbn,
    String? summary,
    required List<String> categoryIds,
  });

  Future<void> toggleFavorite(String id, bool value);
  Future<void> setReadingStatus(String id, ReadingStatus? status);

  // ---------------------------------------------------------------------------
  // Status transitions
  // ---------------------------------------------------------------------------

  /// Move Owned → Wishlist.
  /// MUST clear is_favorite and reading_status at the repository layer.
  /// The schema trigger is a backstop, not the primary gate.
  Future<void> moveToWishlist(String id);

  /// Move Wishlist → Owned.
  /// Does NOT auto-set any reading tier or favorite — those are explicit actions.
  Future<void> moveToOwned(String id);

  // ---------------------------------------------------------------------------
  // Delete / undo
  // ---------------------------------------------------------------------------

  /// Soft delete: sets deleted_at immediately. The UI shows a 4-second undo
  /// snackbar on the root scaffold.
  Future<void> softDelete(String id);

  /// Undo: clears deleted_at. Must be called before sweepExpiredDeletes
  /// runs for this id.
  Future<void> restore(String id);

  // ---------------------------------------------------------------------------
  // Wishlist reorder (fractional indexing)
  // ---------------------------------------------------------------------------

  /// Reorder [id] between two neighbors identified by their sort_order values.
  /// Pass null for [prevOrder] / [nextOrder] to mean "before first" / "after last".
  /// Only the moved row's sort_order and updated_at are touched.
  Future<void> reorder(String id, double? prevOrder, double? nextOrder);

  /// Sort order to use when appending a new wishlist book (max + 1000).
  Future<double> getAppendSortOrder();

  // ---------------------------------------------------------------------------
  // Maintenance
  // ---------------------------------------------------------------------------

  /// Hard-delete rows whose deleted_at < [cutoffMs] and remove their cover
  /// image files. Called post-first-frame to keep it off the cold-start path.
  Future<void> sweepExpiredDeletes(int cutoffMs);

  // ---------------------------------------------------------------------------
  // Duplicate check
  // ---------------------------------------------------------------------------

  /// True if a book with the same normalized (lowercase + trimmed) title AND
  /// author already exists in the active (non-deleted) library.
  Future<bool> isDuplicate(String title, String? author);

  // ---------------------------------------------------------------------------
  // Backup
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> exportToJson();
  Future<void> importFromJson(
    Map<String, dynamic> data, {
    required bool replaceAll,
  });
}
