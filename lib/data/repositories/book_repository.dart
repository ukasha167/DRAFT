import '../../domain/models/book.dart';
import '../../core/utils/omnibox_parser.dart';

abstract class BookRepository {
  Stream<List<Book>> watchBooks({
    required BookStatus status,
    ParsedQuery? query,
  });

  Stream<Book?> watchBook(String id);

  Future<Book?> getBook(String id);

  Future<void> addBook({
    required String title,
    required BookStatus status,
    String? author,
    String? isbn,
    String? summary,
    String? coverUrl,
    String? localCoverPath,
    required List<String> categoryIds,
  });

  Future<void> updateBook({
    required String id,
    required String title,
    String? author,
    String? isbn,
    String? summary,
    String? localCoverPath,
    required List<String> categoryIds,
  });

  Future<void> toggleFavorite(String id, bool value);
  Future<void> setReadingStatus(String id, ReadingStatus? status);

  Future<void> moveToWishlist(String id);

  Future<void> moveToOwned(String id);

  Future<void> softDelete(String id);

  Future<void> restore(String id);

  Future<void> reorder(String id, double? prevOrder, double? nextOrder);

  Future<double> getAppendSortOrder();

  Future<void> sweepExpiredDeletes(int cutoffMs);

  Future<bool> isDuplicate(String title, String? author);

  Future<Map<String, dynamic>> exportToJson();
  Future<void> importFromJson(
    Map<String, dynamic> data, {
    required bool replaceAll,
  });
}
