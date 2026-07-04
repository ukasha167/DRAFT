import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/database.dart';
import '../local/daos/books_dao.dart';
import '../local/daos/categories_dao.dart';
import '../repositories/book_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/book_lookup_repository.dart';
import '../repositories/local/local_book_repository.dart';
import '../repositories/local/local_category_repository.dart';
import '../repositories/api/google_books_repository.dart';

// ---------------------------------------------------------------------------
// Documents directory (resolved once at startup in main.dart)
// ---------------------------------------------------------------------------

/// The absolute path to the app's documents directory, resolved once at
/// startup and injected here. All cover image paths in the DB are stored
/// relative to this directory — never as absolute paths, which change on iOS
/// after a clean build or reinstall.
final docsDirProvider = Provider<String>((_) => throw UnimplementedError(
      'docsDirProvider must be overridden in ProviderScope.',
    ));

// ---------------------------------------------------------------------------
// Database (overridden in ProviderScope at startup)
// ---------------------------------------------------------------------------

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'databaseProvider must be overridden in ProviderScope with an AppDatabase instance.',
  );
});

// ---------------------------------------------------------------------------
// DAOs (derived from the database)
// ---------------------------------------------------------------------------

final booksDaoProvider = Provider<BooksDao>((ref) {
  return ref.watch(databaseProvider).booksDao;
});

final categoriesDaoProvider = Provider<CategoriesDao>((ref) {
  return ref.watch(databaseProvider).categoriesDao;
});

// ---------------------------------------------------------------------------
// Repository implementations
// ---------------------------------------------------------------------------

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final booksDao = ref.watch(booksDaoProvider);
  final categoriesDao = ref.watch(categoriesDaoProvider);
  return LocalBookRepository(db, booksDao, categoriesDao);
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final categoriesDao = ref.watch(categoriesDaoProvider);
  return LocalCategoryRepository(categoriesDao);
});

final bookLookupRepositoryProvider = Provider<BookLookupRepository>((ref) {
  return GoogleBooksRepository();
});
