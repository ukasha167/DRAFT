part of 'categories_dao.dart';

mixin _$CategoriesDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $BookCategoriesTable get bookCategories => attachedDatabase.bookCategories;
  CategoriesDaoManager get managers => CategoriesDaoManager(this);
}

class CategoriesDaoManager {
  final _$CategoriesDaoMixin _db;
  CategoriesDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$BookCategoriesTableTableManager get bookCategories =>
      $$BookCategoriesTableTableManager(
        _db.attachedDatabase,
        _db.bookCategories,
      );
}
