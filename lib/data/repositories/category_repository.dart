import '../../domain/models/category.dart';

abstract class CategoryRepository {
  /// Live stream of user-defined (non-system) categories, A–Z.
  Stream<List<Category>> watchCategories();

  Future<List<Category>> getCategories();

  Future<List<Category>> getCategoriesForBook(String bookId);

  /// True if a category with [normalizedName] already exists.
  /// [excludeId] lets you exclude the category being renamed.
  Future<bool> isDuplicateName(String normalizedName, {String? excludeId});

  /// Create a new category. Returns the created row.
  Future<Category> createCategory(String name);

  Future<void> renameCategory(String id, String newName);

  /// Returns the number of active books that have this category, used
  /// to populate the "N books will be untagged" confirmation dialog.
  Future<int> getBookCountForCategory(String id);

  /// Delete [id] and fall back any exclusively-tagged books to 'uncategorized'.
  /// Requires a prior confirmation that states the affected book count.
  Future<void> deleteCategory(String id);

  /// Replace all category assignments for a book atomically.
  /// Enforces the min-1-category invariant (falls back to uncategorized).
  /// Called by both the Edit chip-removal flow and the Manage Categories
  /// deletion fallback — single code path, not duplicated per screen.
  Future<void> setBookCategories(String bookId, List<String> categoryIds);
}
