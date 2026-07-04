import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../domain/models/category.dart';
import 'daos/books_dao.dart';
import 'daos/categories_dao.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Table definitions
// ---------------------------------------------------------------------------

/// @DataClassName controls the generated Dart row class name, keeping it
/// distinct from the domain model 'Book' in lib/domain/models/book.dart.
@DataClassName('BookRow')
class Books extends Table {
  /// UUID v4 — client-generated. Never autoincrement: two devices must not
  /// collide once cloud sync ships. Retrofitting this after real data exists
  /// is a painful migration; cheap to decide now.
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();

  /// 'owned' | 'wishlist'. Enforced by trigger + repository layer.
  TextColumn get status => text().withDefault(const Constant('wishlist'))();

  /// 'not_started' | 'reading' | 'finished'. Owned only; NULL for Wishlist.
  TextColumn get readingStatus => text().nullable()();

  /// Owned only; 0 for Wishlist. Enforced by trigger + schema-level backstop.
  IntColumn get isFavorite =>
      integer().withDefault(const Constant(0))();

  TextColumn get isbn => text().nullable()();
  TextColumn get summary => text().nullable()();

  /// ~150px thumbnail path — list rows only decode this.
  TextColumn get coverThumbPath => text().nullable()();

  /// Full-res path — decoded only when the detail screen opens.
  TextColumn get coverFullPath => text().nullable()();

  /// REAL, not INTEGER — fractional/sparse positioning for Wishlist reorder.
  /// A drag only touches the moved row's sort_order and updated_at.
  RealColumn get sortOrder =>
      real().withDefault(const Constant(0.0))();

  /// Epoch ms — needed for last-write-wins conflict resolution when sync ships.
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Soft delete: set to now() immediately; swept after ~60s on startup.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Lowercased + trimmed — the UNIQUE constraint enforces case-insensitive dedup.
  TextColumn get nameNormalized => text().unique()();

  /// 1 = 'Uncategorized' system category; seeded once, never deletable.
  IntColumn get isSystem =>
      integer().withDefault(const Constant(0))();

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

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(
  tables: [Books, Categories, BookCategories],
  daos: [BooksDao, CategoriesDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// In-memory database for tests — real SQLite engine, no mocking.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

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
          // Future schema migrations here.
        },
        beforeOpen: (details) async {
          // Applied every open — not just on create.
          await customStatement('PRAGMA journal_mode=WAL;');
          await customStatement('PRAGMA foreign_keys=ON;');
        },
      );

  // --------------------------------------------------------------------------
  // Migration helpers
  // --------------------------------------------------------------------------

  /// SQLite cannot add table-level CHECK constraints after creation.
  /// We enforce the owned/wishlist invariant with BEFORE INSERT/UPDATE triggers
  /// instead. These are the backstop; the repository layer is the primary gate.
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
    // External-content table: FTS5 stores only tokens; triggers sync data.
    // The books table has a UUID text PK but SQLite still maintains an implicit
    // integer rowid — this is what FTS5 uses for the content_rowid mapping.
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
    // Composite: covers both filter (status + deleted_at) and sort (sort_order)
    // for the Wishlist query pattern — single index scan.
    await customStatement(
      'CREATE INDEX idx_books_wishlist_order ON books(status, deleted_at, sort_order);',
    );
  }

  Future<void> _seedSystemData() async {
    // Uncategorized stays as the DB-level fallback (never shown in UI).
    await into(categories).insertOnConflictUpdate(
      const CategoriesCompanion(
        id: Value('uncategorized'),
        name: Value('Uncategorized'),
        nameNormalized: Value('uncategorized'),
        isSystem: Value(1),
      ),
    );

    // Hardcoded taxonomy — seed all 20 predefined categories.
    // Uses insertOnConflictUpdate so re-running on an existing DB is safe.
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
