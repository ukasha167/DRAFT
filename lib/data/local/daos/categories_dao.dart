import 'package:drift/drift.dart';
import '../database.dart';

part 'categories_dao.g.dart';

@DriftAccessor(tables: [Categories, BookCategories])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(super.db);

  static const uncategorizedId = 'uncategorized';

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// All non-system categories, alphabetically. Used by pickers and
  /// the Manage Categories screen. System categories (Uncategorized) are
  /// filtered here — they appear only as automatic fallbacks, not as
  /// selectable options.
  Stream<List<CategoryRow>> watchUserCategories() {
    return (select(categories)
          ..where((t) => t.isSystem.equals(0))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  /// All categories including system — used for export and tests.
  Future<List<CategoryRow>> getAll() => select(categories).get();

  Future<CategoryRow?> getByNormalizedName(String normalized) {
    return (select(categories)
          ..where((t) => t.nameNormalized.equals(normalized)))
        .getSingleOrNull();
  }

  Future<List<CategoryRow>> getForBook(String bookId) async {
    final rows = await customSelect(
      'SELECT c.* FROM categories c '
      'JOIN book_categories bc ON c.id = bc.category_id '
      'WHERE bc.book_id = ? '
      'ORDER BY c.name ASC',
      variables: [Variable(bookId)],
      readsFrom: {categories, bookCategories},
    ).get();

    return rows
        .map((r) => CategoryRow(
              id: r.read<String>('id'),
              name: r.read<String>('name'),
              nameNormalized: r.read<String>('name_normalized'),
              isSystem: r.read<int>('is_system'),
            ))
        .toList();
  }

  /// Batch-load categories for multiple books in a single query.
  /// Returns a map of bookId → List<CategoryRow>. Avoids N+1 queries
  /// when enriching a list of books.
  Future<Map<String, List<CategoryRow>>> getForBooks(
      List<String> bookIds) async {
    if (bookIds.isEmpty) return {};

    final placeholders = List.filled(bookIds.length, '?').join(',');
    final rows = await customSelect(
      'SELECT bc.book_id, c.* FROM categories c '
      'JOIN book_categories bc ON c.id = bc.category_id '
      'WHERE bc.book_id IN ($placeholders) '
      'ORDER BY c.name ASC',
      variables: bookIds.map(Variable.new).toList(),
      readsFrom: {categories, bookCategories},
    ).get();

    final result = <String, List<CategoryRow>>{};
    for (final r in rows) {
      final bookId = r.read<String>('book_id');
      result.putIfAbsent(bookId, () => []).add(CategoryRow(
            id: r.read<String>('id'),
            name: r.read<String>('name'),
            nameNormalized: r.read<String>('name_normalized'),
            isSystem: r.read<int>('is_system'),
          ));
    }
    return result;
  }

  /// How many active (non-deleted) books are tagged with this category.
  /// Used to populate the confirmation dialog before deletion.
  Future<int> getBookCount(String categoryId) async {
    final row = await customSelect(
      'SELECT COUNT(DISTINCT bc.book_id) AS n '
      'FROM book_categories bc '
      'JOIN books b ON b.id = bc.book_id '
      'WHERE bc.category_id = ? AND b.deleted_at IS NULL',
      variables: [Variable(categoryId)],
      readsFrom: {bookCategories, db.books},
    ).getSingle();
    return row.read<int>('n');
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  Future<CategoryRow> insert(String id, String name, String nameNormalized) async {
    await into(categories).insert(CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      nameNormalized: Value(nameNormalized),
    ));
    return (await (select(categories)..where((t) => t.id.equals(id)))
        .getSingle());
  }

  Future<void> rename(
      String id, String newName, String newNameNormalized) async {
    await (update(categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        name: Value(newName),
        nameNormalized: Value(newNameNormalized),
      ),
    );
  }

  /// Delete a category and ensure no book drops to zero categories.
  /// Books exclusively tagged with [id] are reassigned to 'uncategorized'
  /// before the category is deleted. This runs in a transaction.
  Future<void> deleteWithFallback(String id) async {
    await transaction(() async {
      // Find books that would end up with zero categories after deletion.
      final orphanRows = await customSelect(
        'SELECT book_id FROM book_categories '
        'WHERE category_id = ? '
        'AND book_id NOT IN ('
        '  SELECT book_id FROM book_categories WHERE category_id != ?'
        ')',
        variables: [Variable(id), Variable(id)],
        readsFrom: {bookCategories},
      ).map((r) => r.read<String>('book_id')).get();

      // Assign those books to Uncategorized.
      for (final bookId in orphanRows) {
        await into(bookCategories).insertOnConflictUpdate(
          BookCategoriesCompanion(
            bookId: Value(bookId),
            categoryId: const Value(uncategorizedId),
          ),
        );
      }

      // Now safe to remove all uses of this category and delete it.
      await (delete(bookCategories)
            ..where((t) => t.categoryId.equals(id)))
          .go();
      await (delete(categories)..where((t) => t.id.equals(id))).go();
    });
  }

  // ---------------------------------------------------------------------------
  // Book ↔ category link management
  // ---------------------------------------------------------------------------

  /// Replace all category assignments for [bookId] in one transaction.
  /// Enforces minimum-1 by falling back to uncategorized when [categoryIds]
  /// is empty. This is the single code path used by both the Edit chip-removal
  /// flow and the Manage Categories deletion flow.
  Future<void> setBookCategories(
      String bookId, List<String> categoryIds) async {
    final effectiveIds =
        categoryIds.isEmpty ? [uncategorizedId] : categoryIds;

    await transaction(() async {
      await (delete(bookCategories)
            ..where((t) => t.bookId.equals(bookId)))
          .go();
      for (final catId in effectiveIds) {
        await into(bookCategories).insert(
          BookCategoriesCompanion(
            bookId: Value(bookId),
            categoryId: Value(catId),
          ),
        );
      }
    });
  }
}
