# DRAFT.

Offline-first personal book catalog. Owned / Wishlist collections, multi-category tagging, FTS5 full-text search, Google Books API lookup, and a typed omnibox.

## Architecture

```
UI (widgets / screens)
   ↓ reads/writes via
State (Riverpod StateNotifiers / StreamProviders)
   ↓ calls
Repository interfaces (abstract — swap local ↔ cloud later without touching a widget)
   ↓ implemented by
Data layer (drift + SQLite FTS5 locally)
```

Feature-based folder structure under `lib/features/`. Domain models in `lib/domain/models/` are decoupled from drift's generated row types — mapping happens at the repository boundary.

## Setup

### 1. Font assets

Download [Manrope](https://fonts.google.com/specimen/Manrope) and place these files under `assets/fonts/`:
- `Manrope-Regular.ttf`
- `Manrope-Medium.ttf`
- `Manrope-SemiBold.ttf`
- `Manrope-Bold.ttf`
- `Manrope-ExtraBold.ttf`

### 2. Google Books API key

In `lib/data/repositories/api/google_books_repository.dart`, set your API key:
```dart
static const _apiKey = 'YOUR_GOOGLE_BOOKS_API_KEY';
```
Restrict it in Google Cloud Console to your app's package name + signing certificate.

### 3. Install and generate

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

The `build_runner` step generates:
- `lib/data/local/database.g.dart` — drift database + table companions
- `lib/data/local/daos/books_dao.g.dart`
- `lib/data/local/daos/categories_dao.g.dart`

### 4. Tests

```bash
flutter test
```

Tests run against an in-memory SQLite database — no mocks, real SQL behavior including CHECK triggers and FTS5.

## Key decisions (from spec, do not relitigate)

- **UUID PKs** — collision-safe for future cloud sync
- **`sort_order REAL`** — fractional/sparse positioning; a drag touches one row
- **FTS5 external-content** — `books_fts` stays in sync via triggers
- **No swipe-to-delete** — long-press only; accidental trigger risk on destructive actions
- **Max 4 categories** — fits on a 64px row without growth; revisit if row height changes
- **Soft delete sweep post-first-frame** — file I/O off the cold-start critical path
- **`connectivity_plus` as pre-check only** — actual offline gate is request timeout
