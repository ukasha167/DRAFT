import '../../../core/utils/uuid_helper.dart';
import '../../../domain/models/category.dart';
import '../../local/daos/categories_dao.dart';
import '../../local/database.dart';
import '../category_repository.dart';

class LocalCategoryRepository implements CategoryRepository {
  final CategoriesDao _dao;

  const LocalCategoryRepository(this._dao);

  @override
  Stream<List<Category>> watchCategories() {
    return _dao.watchUserCategories().map(
          (rows) => rows.map(_map).toList(),
        );
  }

  @override
  Future<List<Category>> getCategories() async {
    final rows = await _dao.getAll();
    return rows.map(_map).toList();
  }

  @override
  Future<List<Category>> getCategoriesForBook(String bookId) async {
    final rows = await _dao.getForBook(bookId);
    return rows.map(_map).toList();
  }

  @override
  Future<bool> isDuplicateName(String normalizedName,
      {String? excludeId}) async {
    final existing = await _dao.getByNormalizedName(normalizedName);
    if (existing == null) return false;
    if (excludeId != null && existing.id == excludeId) return false;
    return true;
  }

  @override
  Future<Category> createCategory(String name) async {
    final normalized = Category.normalize(name);
    final id = newId();
    final row = await _dao.insert(id, name, normalized);
    return _map(row);
  }

  @override
  Future<void> renameCategory(String id, String newName) async {
    final normalized = Category.normalize(newName);
    await _dao.rename(id, newName, normalized);
  }

  @override
  Future<int> getBookCountForCategory(String id) {
    return _dao.getBookCount(id);
  }

  @override
  Future<void> deleteCategory(String id) {
    // deleteWithFallback handles the uncategorized reassignment atomically.
    return _dao.deleteWithFallback(id);
  }

  @override
  Future<void> setBookCategories(
      String bookId, List<String> categoryIds) {
    // min-1 enforcement lives inside the DAO's setBookCategories.
    return _dao.setBookCategories(bookId, categoryIds);
  }

  Category _map(CategoryRow row) => Category(
        id: row.id,
        name: row.name,
        nameNormalized: row.nameNormalized,
        isSystem: row.isSystem == 1,
      );
}
