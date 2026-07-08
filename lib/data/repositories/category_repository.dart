import '../../domain/models/category.dart';

abstract class CategoryRepository {
  Stream<List<Category>> watchCategories();

  Future<List<Category>> getCategories();

  Future<List<Category>> getCategoriesForBook(String bookId);

  Future<bool> isDuplicateName(String normalizedName, {String? excludeId});

  Future<Category> createCategory(String name);

  Future<void> renameCategory(String id, String newName);

  Future<int> getBookCountForCategory(String id);

  Future<void> deleteCategory(String id);

  Future<void> setBookCategories(String bookId, List<String> categoryIds);
}
