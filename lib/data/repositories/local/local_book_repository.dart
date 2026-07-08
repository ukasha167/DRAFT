import 'package:drift/drift.dart';

import '../../../core/utils/image_utils.dart';
import '../../../core/utils/omnibox_parser.dart';
import '../../../core/utils/uuid_helper.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/category.dart';
import '../../local/daos/books_dao.dart';
import '../../local/daos/categories_dao.dart';
import '../../local/database.dart';
import '../book_repository.dart';

class LocalBookRepository implements BookRepository {
  final BooksDao _booksDao;
  final CategoriesDao _categoriesDao;
  final AppDatabase _db;

  const LocalBookRepository(this._db, this._booksDao, this._categoriesDao);

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  @override
  Stream<List<Book>> watchBooks({
    required BookStatus status,
    ParsedQuery? query,
  }) {
    final baseStream = status == BookStatus.owned
        ? _booksDao.watchOwned()
        : _booksDao.watchWishlist();

    return baseStream.asyncMap((rows) async {
      // Batch-load all categories in one query — avoids N+1.
      final bookIds = rows.map((r) => r.id).toList();
      final catsByBook = await _categoriesDao.getForBooks(bookIds);

      var books = rows.map((row) {
        final cats = (catsByBook[row.id] ?? []).map(_mapCategory).toList();
        return _mapBook(row, cats);
      }).toList();

      // Apply #category filter (AND logic: book must have ALL requested cats).
      if (query?.categories.isNotEmpty == true) {
        books = books.where((b) => query!.categories.every(
              (slug) =>
                  b.categories.any((c) => c.nameNormalized == slug),
            )).toList();
      }

      // Apply FTS5 text filter.
      if (query?.text?.isNotEmpty == true) {
        final hits = await _booksDao.fullTextSearch(query!.text!);
        final hitIds = hits.map((r) => r.id).toSet();
        books = books.where((b) => hitIds.contains(b.id)).toList();
      }

      return books;
    });
  }

  @override
  Stream<Book?> watchBook(String id) {
    return _booksDao.watchById(id).asyncMap((row) async {
      if (row == null) return null;
      final cats = await _categoriesDao.getForBook(id);
      return _mapBook(row, cats.map(_mapCategory).toList());
    });
  }

  @override
  Future<Book?> getBook(String id) async {
    final row = await _booksDao.getById(id);
    if (row == null) return null;
    final cats = await _categoriesDao.getForBook(id);
    return _mapBook(row, cats.map(_mapCategory).toList());
  }

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  @override
  Future<void> addBook({
    required String title,
    required BookStatus status,
    String? author,
    String? isbn,
    String? summary,
    String? coverUrl,
    String? localCoverPath,
    required List<String> categoryIds,
  }) async {
    final id = newId();
    final now = nowMs();

    // Local file takes priority; fall back to remote URL download.
    CoverPaths? coverPaths;
    if (localCoverPath != null && localCoverPath.isNotEmpty) {
      coverPaths = await processLocalFileCover(localCoverPath);
    } else if (coverUrl != null && coverUrl.isNotEmpty) {
      coverPaths = await downloadAndProcessCover(coverUrl);
    }

    double sortOrder = 0.0;
    if (status == BookStatus.wishlist) {
      final max = await _booksDao.getMaxWishlistSortOrder();
      sortOrder = max + 1000.0;
    }

    await _db.transaction(() async {
      await _booksDao.insertBook(BooksCompanion(
        id: Value(id),
        title: Value(title),
        author: Value(author),
        status: Value(_statusToDb(status)),
        isbn: Value(isbn),
        summary: Value(summary),
        coverThumbPath: Value(coverPaths?.thumbPath),
        coverFullPath: Value(coverPaths?.fullPath),
        sortOrder: Value(sortOrder),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));
      await _categoriesDao.setBookCategories(id, categoryIds);
    });
  }

  // ---------------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------------

  @override
  Future<void> updateBook({
    required String id,
    required String title,
    String? author,
    String? isbn,
    String? summary,
    String? localCoverPath,
    required List<String> categoryIds,
  }) async {
    CoverPaths? coverPaths;
    if (localCoverPath != null && localCoverPath.isNotEmpty) {
      coverPaths = await processLocalFileCover(localCoverPath);
    }

    // Build the base companion; Drift companions don't support if-spread
    // inside the constructor, so we use copyWith for the optional cover fields.
    var companion = BooksCompanion(
      title: Value(title),
      author: Value(author),
      isbn: Value(isbn),
      summary: Value(summary),
      updatedAt: Value(nowMs()),
    );

    if (coverPaths != null) {
      companion = companion.copyWith(
        coverThumbPath: Value(coverPaths.thumbPath),
        coverFullPath: Value(coverPaths.fullPath),
      );
    }

    await _db.transaction(() async {
      await _booksDao.updateBook(companion, id);
      await _categoriesDao.setBookCategories(id, categoryIds);
    });
  }


  @override
  Future<void> toggleFavorite(String id, bool value) {
    return _booksDao.updateBook(
      BooksCompanion(
        isFavorite: Value(value ? 1 : 0),
        updatedAt: Value(nowMs()),
      ),
      id,
    );
  }

  @override
  Future<void> setReadingStatus(String id, ReadingStatus? status) {
    return _booksDao.updateBook(
      BooksCompanion(
        readingStatus: Value(status?.dbValue),
        updatedAt: Value(nowMs()),
      ),
      id,
    );
  }

  // ---------------------------------------------------------------------------
  // Status transitions
  // ---------------------------------------------------------------------------

  @override
  Future<void> moveToWishlist(String id) async {
    final max = await _booksDao.getMaxWishlistSortOrder();
    await _booksDao.updateBook(
      BooksCompanion(
        status: const Value('wishlist'),
        // MUST clear — schema trigger enforces this; repository clears for
        // clean error handling and so consumers see a clean state immediately.
        isFavorite: const Value(0),
        readingStatus: const Value(null),
        sortOrder: Value(max + 1000.0),
        updatedAt: Value(nowMs()),
      ),
      id,
    );
  }

  @override
  Future<void> moveToOwned(String id) {
    return _booksDao.updateBook(
      BooksCompanion(
        status: const Value('owned'),
        updatedAt: Value(nowMs()),
      ),
      id,
    );
  }

  // ---------------------------------------------------------------------------
  // Delete / undo
  // ---------------------------------------------------------------------------

  @override
  Future<void> softDelete(String id) {
    return _booksDao.softDelete(id, nowMs());
  }

  @override
  Future<void> restore(String id) {
    return _booksDao.restore(id, nowMs());
  }

  // ---------------------------------------------------------------------------
  // Wishlist reorder
  // ---------------------------------------------------------------------------

  @override
  Future<void> reorder(String id, double? prevOrder, double? nextOrder) {
    final double newOrder;
    if (prevOrder == null && nextOrder == null) {
      newOrder = 1000.0;
    } else if (prevOrder == null) {
      newOrder = nextOrder! / 2.0;
    } else if (nextOrder == null) {
      newOrder = prevOrder + 1000.0;
    } else {
      newOrder = (prevOrder + nextOrder) / 2.0;
    }
    return _booksDao.updateSortOrder(id, newOrder, nowMs());
  }

  @override
  Future<double> getAppendSortOrder() async {
    final max = await _booksDao.getMaxWishlistSortOrder();
    return max + 1000.0;
  }

  // ---------------------------------------------------------------------------
  // Maintenance
  // ---------------------------------------------------------------------------

  @override
  Future<void> sweepExpiredDeletes(int cutoffMs) async {
    final expired = await _booksDao.getExpired(cutoffMs);
    for (final row in expired) {
      await deleteCoverFiles(row.coverThumbPath, row.coverFullPath);
      await _booksDao.hardDelete(row.id);
    }
  }

  // ---------------------------------------------------------------------------
  // Duplicate check
  // ---------------------------------------------------------------------------

  @override
  Future<bool> isDuplicate(String title, String? author) async {
    final normTitle = title.trim().toLowerCase();
    final normAuthor = author?.trim().toLowerCase();

    // Use FTS5 to find candidates by title, then check exact normalized match.
    if (normTitle.isEmpty) return false;
    final hits = await _booksDao.fullTextSearch(normTitle);
    return hits.any((row) {
      final t = row.title.trim().toLowerCase();
      final a = row.author?.trim().toLowerCase();
      final titleMatch = t == normTitle;
      final authorMatch =
          normAuthor == null || normAuthor.isEmpty || a == normAuthor;
      return titleMatch && authorMatch;
    });
  }

  // ---------------------------------------------------------------------------
  // Backup
  // ---------------------------------------------------------------------------

  @override
  Future<Map<String, dynamic>> exportToJson() async {
    final allBooks = await _db.select(_db.books).get();
    final allCats = await _db.select(_db.categories).get();
    final allLinks = await _db.select(_db.bookCategories).get();

    return {
      'schema_version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'books': allBooks
          .map((b) => {
                'id': b.id,
                'title': b.title,
                'author': b.author,
                'status': b.status,
                'reading_status': b.readingStatus,
                'is_favorite': b.isFavorite,
                'isbn': b.isbn,
                'summary': b.summary,
                'sort_order': b.sortOrder,
                'created_at': b.createdAt,
                'updated_at': b.updatedAt,
                'deleted_at': b.deletedAt,
              })
          .toList(),
      'categories': allCats
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'name_normalized': c.nameNormalized,
                'is_system': c.isSystem,
              })
          .toList(),
      'book_categories': allLinks
          .map((l) => {'book_id': l.bookId, 'category_id': l.categoryId})
          .toList(),
    };
  }

  @override
  Future<void> importFromJson(
    Map<String, dynamic> data, {
    required bool replaceAll,
  }) async {
    final schemaVersion = data['schema_version'] as int? ?? 0;
    if (schemaVersion > 1) {
      throw UnsupportedError(
        'Backup schema version $schemaVersion is newer than '
        'this app version (supports up to 1). Update the app first.',
      );
    }

    await _db.transaction(() async {
      if (replaceAll) {
        await _db.delete(_db.bookCategories).go();
        await _db.delete(_db.books).go();
        // Keep system categories; only wipe user ones.
        await (_db.delete(_db.categories)
              ..where((t) => t.isSystem.equals(0)))
            .go();
      }

      // ── Categories ────────────────────────────────────────────────────────
      // Problem: the same category name can exist locally with a DIFFERENT UUID
      // (created on another device). insertOnConflictUpdate only handles PK
      // conflicts; a name_normalized collision on a different UUID raises a
      // UNIQUE violation instead.
      //
      // Fix: build a backup-uuid → local-uuid remapping table first, then route
      // all book_categories inserts through it. Without this, books end up with
      // category foreign keys pointing at UUIDs that don't exist locally.
      final cats = data['categories'] as List<dynamic>? ?? [];
      final catIdRemap = <String, String>{}; // backup UUID → local UUID

      for (final c in cats) {
        final backupId = c['id'] as String;
        final isSystem = (c['is_system'] as int?) == 1;

        if (isSystem) {
          // Always remap system categories to the fixed local id.
          catIdRemap[backupId] = 'uncategorized';
          continue;
        }

        final normalized = c['name_normalized'] as String;

        // Does this normalized name already exist locally (possibly under a
        // different UUID)?
        final existing = await _categoriesDao.getByNormalizedName(normalized);
        if (existing != null) {
          // Same logical category, different UUID — remap to local UUID.
          // Do NOT overwrite: local naming is authoritative.
          catIdRemap[backupId] = existing.id;
        } else {
          // Genuinely new category — insert it.
          // Use insertOrIgnore as a safety net; a race between two imports of
          // the same name_normalized won't crash, just skips the second.
          await _db.into(_db.categories).insert(
            CategoriesCompanion(
              id: Value(backupId),
              name: Value(c['name'] as String),
              nameNormalized: Value(normalized),
              isSystem: const Value(0),
            ),
            mode: InsertMode.insertOrIgnore,
          );
          catIdRemap[backupId] = backupId;
        }
      }

      // ── Books ─────────────────────────────────────────────────────────────
      // Merge strategy: take whichever has the newer updated_at.
      final books = data['books'] as List<dynamic>? ?? [];
      for (final b in books) {
        final existing = await _booksDao.getById(b['id'] as String);
        final incomingUpdatedAt = b['updated_at'] as int;
        if (existing != null && existing.updatedAt >= incomingUpdatedAt) {
          continue; // Local is newer or equal; skip.
        }
        await _db.into(_db.books).insertOnConflictUpdate(
          BooksCompanion(
            id: Value(b['id'] as String),
            title: Value(b['title'] as String),
            author: Value(b['author'] as String?),
            status: Value(b['status'] as String),
            readingStatus: Value(b['reading_status'] as String?),
            isFavorite: Value(b['is_favorite'] as int),
            isbn: Value(b['isbn'] as String?),
            summary: Value(b['summary'] as String?),
            sortOrder: Value((b['sort_order'] as num).toDouble()),
            createdAt: Value(b['created_at'] as int),
            updatedAt: Value(incomingUpdatedAt),
            deletedAt: Value(b['deleted_at'] as int?),
            // Cover image files don't transfer in JSON backup; paths omitted.
          ),
        );
      }

      // ── Book-category links ───────────────────────────────────────────────
      // Route every category_id through the remapping table. Without this,
      // links from the backup would reference backup UUIDs that were merged
      // into existing local UUIDs and never inserted — silent broken FK.
      final links = data['book_categories'] as List<dynamic>? ?? [];
      for (final l in links) {
        final backupCatId = l['category_id'] as String;
        final localCatId = catIdRemap[backupCatId] ?? backupCatId;

        await _db.into(_db.bookCategories).insertOnConflictUpdate(
          BookCategoriesCompanion(
            bookId: Value(l['book_id'] as String),
            categoryId: Value(localCatId),
          ),
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Mapping helpers — drift row types → domain models
  // ---------------------------------------------------------------------------

  Book _mapBook(BookRow row, List<Category> categories) {
    return Book(
      id: row.id,
      title: row.title,
      author: row.author,
      status: _statusFromDb(row.status),
      readingStatus: ReadingStatus.fromDb(row.readingStatus),
      isFavorite: row.isFavorite == 1,
      isbn: row.isbn,
      summary: row.summary,
      coverThumbPath: row.coverThumbPath,
      coverFullPath: row.coverFullPath,
      sortOrder: row.sortOrder,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
      deletedAt: row.deletedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.deletedAt!)
          : null,
      categories: categories,
    );
  }

  Category _mapCategory(CategoryRow row) {
    return Category(
      id: row.id,
      name: row.name,
      nameNormalized: row.nameNormalized,
      isSystem: row.isSystem == 1,
    );
  }

  static String _statusToDb(BookStatus s) =>
      s == BookStatus.owned ? 'owned' : 'wishlist';

  static BookStatus _statusFromDb(String s) =>
      s == 'owned' ? BookStatus.owned : BookStatus.wishlist;
}
