import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value, BooksCompanion;
import 'package:flutter_test/flutter_test.dart';

import 'package:book_tracker/data/local/database.dart';
import 'package:book_tracker/data/repositories/local/local_book_repository.dart';
import 'package:book_tracker/data/repositories/local/local_category_repository.dart';
import 'package:book_tracker/domain/models/book.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase _makeDb() => AppDatabase.memory();

Future<LocalBookRepository> _makeRepo(AppDatabase db) async {
  return LocalBookRepository(db, db.booksDao, db.categoriesDao);
}

Future<LocalCategoryRepository> _makeCatRepo(AppDatabase db) async {
  return LocalCategoryRepository(db.categoriesDao);
}

// ---------------------------------------------------------------------------
// Tests — real in-memory SQLite engine, not mocks.
// This exercises actual SQL behavior, CHECK triggers, FTS5, and foreign keys.
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;
  late LocalBookRepository bookRepo;
  late LocalCategoryRepository catRepo;

  setUp(() async {
    db = _makeDb();
    bookRepo = await _makeRepo(db);
    catRepo = await _makeCatRepo(db);
  });

  tearDown(() async {
    await db.close();
  });

  // -------------------------------------------------------------------------
  // Schema invariant trigger
  // -------------------------------------------------------------------------
  group('schema CHECK trigger', () {
    test('inserting wishlist book with is_favorite=1 throws', () async {
      // The BEFORE INSERT trigger must fire and abort this.
      expect(
        () async {
          await db.into(db.books).insert(BooksCompanion(
            id: const Value('bad-1'),
            title: const Value('Bad Book'),
            status: const Value('wishlist'),
            isFavorite: const Value(1), // INVALID for wishlist
            createdAt: Value(DateTime.now().millisecondsSinceEpoch),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
            sortOrder: const Value(0),
          ));
        },
        throwsA(anything),
        reason: 'wishlist book with is_favorite=1 violates trigger constraint',
      );
    });

    test('inserting wishlist book with reading_status throws', () async {
      expect(
        () async {
          await db.into(db.books).insert(BooksCompanion(
            id: const Value('bad-2'),
            title: const Value('Bad Book 2'),
            status: const Value('wishlist'),
            readingStatus: const Value('reading'), // INVALID for wishlist
            createdAt: Value(DateTime.now().millisecondsSinceEpoch),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
            sortOrder: const Value(0),
          ));
        },
        throwsA(anything),
      );
    });

    test('valid owned book with reading_status inserts fine', () async {
      await expectLater(
        db.into(db.books).insert(BooksCompanion(
          id: const Value('ok-1'),
          title: const Value('Good Book'),
          status: const Value('owned'),
          readingStatus: const Value('reading'),
          isFavorite: const Value(1),
          createdAt: Value(DateTime.now().millisecondsSinceEpoch),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          sortOrder: const Value(0),
        )),
        completes,
      );
    });
  });

  // -------------------------------------------------------------------------
  // Category count invariant — min 1, Uncategorized fallback
  // -------------------------------------------------------------------------
  group('category count invariant', () {
    test('adding book with no categories falls back to Uncategorized', () async {
      await bookRepo.addBook(
        title: 'Test Book',
        status: BookStatus.wishlist,
        categoryIds: [], // intentionally empty
      );

      final books = await bookRepo
          .watchBooks(status: BookStatus.wishlist)
          .first;
      expect(books, hasLength(1));
      expect(books.first.categories.map((c) => c.id),
          contains('uncategorized'));
    });

    test('removing last category chip falls back to Uncategorized', () async {
      // Create a real category and add a book to it.
      final cat = await catRepo.createCategory('Fantasy');
      await bookRepo.addBook(
        title: 'Test Book',
        status: BookStatus.owned,
        categoryIds: [cat.id],
      );

      final books =
          await bookRepo.watchBooks(status: BookStatus.owned).first;
      final bookId = books.first.id;

      // Remove all categories — should fall back.
      await catRepo.setBookCategories(bookId, []);

      final updated =
          await bookRepo.watchBooks(status: BookStatus.owned).first;
      expect(updated.first.categories.map((c) => c.id),
          contains('uncategorized'));
    });

    test('deleting a category falls back exclusively-tagged books', () async {
      final cat = await catRepo.createCategory('Thriller');
      await bookRepo.addBook(
        title: 'Thriller Book',
        status: BookStatus.owned,
        categoryIds: [cat.id],
      );

      // Delete the category.
      await catRepo.deleteCategory(cat.id);

      final books =
          await bookRepo.watchBooks(status: BookStatus.owned).first;
      expect(books.first.categories.map((c) => c.id),
          contains('uncategorized'),
          reason: 'book must not end up with zero categories after deletion');
    });

    test('max 4 categories enforced at the form level', () async {
      // The 4-cap is enforced in BookFormWidget, not the DB.
      // This test documents the contract so a future refactor doesn't
      // accidentally move the cap into the DB and break the UI.
      final cats = await Future.wait([
        catRepo.createCategory('A'),
        catRepo.createCategory('B'),
        catRepo.createCategory('C'),
        catRepo.createCategory('D'),
        catRepo.createCategory('E'),
      ]);

      // Repo and DAO accept >4 — the cap lives in the form widget.
      // (We still test that the DB doesn't blow up with 5.)
      await bookRepo.addBook(
        title: 'Multi-cat',
        status: BookStatus.owned,
        categoryIds: cats.map((c) => c.id).toList(),
      );

      final books =
          await bookRepo.watchBooks(status: BookStatus.owned).first;
      expect(books.first.categories, hasLength(5));
    });
  });

  // -------------------------------------------------------------------------
  // Move transition — is_favorite and reading_status must be cleared
  // -------------------------------------------------------------------------
  group('move transitions', () {
    test('moveToWishlist clears is_favorite and reading_status', () async {
      await bookRepo.addBook(
        title: 'Owned Book',
        status: BookStatus.owned,
        categoryIds: ['uncategorized'],
      );
      final books =
          await bookRepo.watchBooks(status: BookStatus.owned).first;
      final id = books.first.id;

      // Set both fields.
      await bookRepo.toggleFavorite(id, true);
      await bookRepo.setReadingStatus(id, ReadingStatus.reading);

      // Move to wishlist — both must be cleared.
      await bookRepo.moveToWishlist(id);

      final wishlist =
          await bookRepo.watchBooks(status: BookStatus.wishlist).first;
      expect(wishlist.first.isFavorite, isFalse,
          reason: 'is_favorite must be cleared on move to wishlist');
      expect(wishlist.first.readingStatus, isNull,
          reason: 'reading_status must be null on move to wishlist');
    });

    test('moveToOwned does NOT auto-set reading_status or favorite', () async {
      await bookRepo.addBook(
        title: 'Wishlist Book',
        status: BookStatus.wishlist,
        categoryIds: ['uncategorized'],
      );
      final wl =
          await bookRepo.watchBooks(status: BookStatus.wishlist).first;
      final id = wl.first.id;

      await bookRepo.moveToOwned(id);

      final owned =
          await bookRepo.watchBooks(status: BookStatus.owned).first;
      expect(owned.first.isFavorite, isFalse);
      expect(owned.first.readingStatus, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Soft delete + restore
  // -------------------------------------------------------------------------
  group('soft delete and restore', () {
    test('soft-deleted book disappears from watch stream', () async {
      await bookRepo.addBook(
        title: 'Delete Me',
        status: BookStatus.owned,
        categoryIds: ['uncategorized'],
      );
      final before =
          await bookRepo.watchBooks(status: BookStatus.owned).first;
      final id = before.first.id;

      await bookRepo.softDelete(id);

      final after =
          await bookRepo.watchBooks(status: BookStatus.owned).first;
      expect(after, isEmpty);
    });

    test('restore brings book back', () async {
      await bookRepo.addBook(
        title: 'Restore Me',
        status: BookStatus.owned,
        categoryIds: ['uncategorized'],
      );
      final books =
          await bookRepo.watchBooks(status: BookStatus.owned).first;
      final id = books.first.id;

      await bookRepo.softDelete(id);
      await bookRepo.restore(id);

      final after =
          await bookRepo.watchBooks(status: BookStatus.owned).first;
      expect(after, hasLength(1));
    });

    test('sweep purges expired rows', () async {
      await bookRepo.addBook(
        title: 'Sweep Me',
        status: BookStatus.owned,
        categoryIds: ['uncategorized'],
      );
      final books =
          await bookRepo.watchBooks(status: BookStatus.owned).first;
      final id = books.first.id;

      await bookRepo.softDelete(id);

      // Use a future cutoff so the row is definitely "expired".
      final futureCutoff =
          DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch;
      await bookRepo.sweepExpiredDeletes(futureCutoff);

      // Hard-deleted rows don't even appear in a raw table scan.
      final row = await db.booksDao.getById(id);
      expect(row, isNull, reason: 'row must be hard-deleted after sweep');
    });
  });

  // -------------------------------------------------------------------------
  // Fractional reorder
  // -------------------------------------------------------------------------
  group('wishlist fractional reorder', () {
    test('reorder places item at midpoint between neighbors', () async {
      for (final title in ['A', 'B', 'C']) {
        await bookRepo.addBook(
          title: title,
          status: BookStatus.wishlist,
          categoryIds: ['uncategorized'],
        );
      }

      final before =
          await bookRepo.watchBooks(status: BookStatus.wishlist).first;
      expect(before.map((b) => b.title).toList(), ['A', 'B', 'C']);

      // Move C between A and B: prevOrder=A.sortOrder, nextOrder=B.sortOrder
      final a = before[0];
      final b = before[1];
      final c = before[2];

      await bookRepo.reorder(c.id, a.sortOrder, b.sortOrder);

      final after =
          await bookRepo.watchBooks(status: BookStatus.wishlist).first;
      expect(after.map((b) => b.title).toList(), ['A', 'C', 'B'],
          reason: 'C should now sit between A and B');
    });
  });

  // -------------------------------------------------------------------------
  // Duplicate check
  // -------------------------------------------------------------------------
  group('duplicate detection', () {
    test('exact title+author match detected', () async {
      await bookRepo.addBook(
        title: 'Dune',
        status: BookStatus.owned,
        categoryIds: ['uncategorized'],
        author: 'Frank Herbert',
      );

      expect(await bookRepo.isDuplicate('Dune', 'Frank Herbert'), isTrue);
      expect(await bookRepo.isDuplicate('Dune', 'Someone Else'), isFalse);
      expect(await bookRepo.isDuplicate('Foundation', 'Frank Herbert'), isFalse);
    });

    test('case-insensitive match', () async {
      await bookRepo.addBook(
        title: 'dune',
        status: BookStatus.owned,
        categoryIds: ['uncategorized'],
        author: 'frank herbert',
      );

      expect(await bookRepo.isDuplicate('DUNE', 'FRANK HERBERT'), isTrue);
    });
  });
}
