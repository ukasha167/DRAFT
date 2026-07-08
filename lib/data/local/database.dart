import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../domain/models/category.dart';
import 'daos/books_dao.dart';
import 'daos/categories_dao.dart';

part 'database.g.dart';

@DataClassName('BookRow')
class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();

  TextColumn get status => text().withDefault(const Constant('wishlist'))();

  TextColumn get readingStatus => text().nullable()();

  IntColumn get isFavorite => integer().withDefault(const Constant(0))();

  TextColumn get isbn => text().nullable()();
  TextColumn get summary => text().nullable()();

  TextColumn get coverThumbPath => text().nullable()();

  TextColumn get coverFullPath => text().nullable()();

  TextColumn get dominantColor => text().nullable()();

  RealColumn get sortOrder => real().withDefault(const Constant(0.0))();

  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  TextColumn get nameNormalized => text().unique()();

  IntColumn get isSystem => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('BookCategoryRow')
class BookCategories extends Table {
  TextColumn get bookId => text()();
  TextColumn get categoryId => text()();

  @override
  Set<Column> get primaryKey => {bookId, categoryId};
}

@DriftDatabase(
  tables: [Books, Categories, BookCategories],
  daos: [BooksDao, CategoriesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _applyInvariantTriggers();
      await _createFts5();
      await _createIndexes();
      await _seedSystemData();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(books, books.dominantColor);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA journal_mode=WAL;');
      await customStatement('PRAGMA foreign_keys=ON;');
    },
  );

  Future<void> _applyInvariantTriggers() async {
    const _sql = '''
      SELECT CASE
        WHEN NEW.status NOT IN ('owned', 'wishlist')
          THEN RAISE(ABORT, 'CHK: invalid status')
        WHEN NEW.status = 'wishlist' AND NEW.is_favorite != 0
          THEN RAISE(ABORT, 'CHK: wishlist cannot be favorite')
        WHEN NEW.status = 'wishlist' AND NEW.reading_status IS NOT NULL
          THEN RAISE(ABORT, 'CHK: wishlist cannot have reading_status')
        WHEN NEW.reading_status IS NOT NULL
         AND NEW.reading_status NOT IN ('not_started','reading','finished')
          THEN RAISE(ABORT, 'CHK: invalid reading_status')
      END;
    ''';

    await customStatement('''
      CREATE TRIGGER trg_books_inv_insert BEFORE INSERT ON books BEGIN
        $_sql
      END;
    ''');
    await customStatement('''
      CREATE TRIGGER trg_books_inv_update BEFORE UPDATE ON books BEGIN
        $_sql
      END;
    ''');
  }

  Future<void> _createFts5() async {
    await customStatement('''
      CREATE VIRTUAL TABLE books_fts USING fts5(
        title, author, summary,
        content='books',
        content_rowid='rowid'
      );
    ''');
    await customStatement('''
      CREATE TRIGGER books_ai AFTER INSERT ON books BEGIN
        INSERT INTO books_fts(rowid, title, author, summary)
        VALUES (new.rowid, new.title, new.author, new.summary);
      END;
    ''');
    await customStatement('''
      CREATE TRIGGER books_ad AFTER DELETE ON books BEGIN
        INSERT INTO books_fts(books_fts, rowid, title, author, summary)
        VALUES('delete', old.rowid, old.title, old.author, old.summary);
      END;
    ''');
    await customStatement('''
      CREATE TRIGGER books_au AFTER UPDATE ON books BEGIN
        INSERT INTO books_fts(books_fts, rowid, title, author, summary)
        VALUES('delete', old.rowid, old.title, old.author, old.summary);
        INSERT INTO books_fts(rowid, title, author, summary)
        VALUES (new.rowid, new.title, new.author, new.summary);
      END;
    ''');
  }

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX idx_books_status ON books(status, deleted_at);',
    );
    await customStatement(
      'CREATE INDEX idx_books_wishlist_order ON books(status, deleted_at, sort_order);',
    );
  }

  Future<void> _seedSystemData() async {
    await into(categories).insertOnConflictUpdate(
      const CategoriesCompanion(
        id: Value('uncategorized'),
        name: Value('Uncategorized'),
        nameNormalized: Value('uncategorized'),
        isSystem: Value(1),
      ),
    );

    for (final cat in kCategories) {
      await into(categories).insertOnConflictUpdate(
        CategoriesCompanion(
          id: Value(cat.id),
          name: Value(cat.name),
          nameNormalized: Value(cat.nameNormalized),
          isSystem: const Value(1),
        ),
      );
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'books.db'));
    return NativeDatabase.createInBackground(file);
  });
}
