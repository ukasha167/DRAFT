import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debouncer.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/category.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../add_book/screens/add_book_sheet.dart';
import '../../book_detail/screens/book_detail_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../providers/library_providers.dart';
import '../widgets/book_grid_item.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchCtrl = TextEditingController();
  final _debouncer  = Debouncer(delay: const Duration(milliseconds: 150));

  @override
  void initState() {
    super.initState();
    // Post-first-frame sweep: purge soft-deleted rows + orphaned cover files.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sweep());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> _sweep() async {
    final cutoff = DateTime.now()
        .subtract(const Duration(seconds: 60))
        .millisecondsSinceEpoch;
    await ref.read(bookRepositoryProvider).sweepExpiredDeletes(cutoff);
  }

  void _switchTab(BookStatus to) {
    ref.read(currentTabProvider.notifier).state = to;
    ref.read(activeCategoryProvider.notifier).state = null; // reset filter
  }

  void _softDelete(Book book) {
    ref.read(bookRepositoryProvider).softDelete(book.id);
    ref.read(lastDeletedProvider.notifier).state =
        (id: book.id, title: book.title);

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('"${book.title}" deleted'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            final d = ref.read(lastDeletedProvider);
            if (d != null) {
              ref.read(bookRepositoryProvider).restore(d.id);
              ref.read(lastDeletedProvider.notifier).state = null;
            }
          },
        ),
      ));
  }

  Future<void> _openAdd() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddBookSheet(),
    );
  }

  void _openDetail(Book book) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id)));
  }

  @override
  Widget build(BuildContext context) {
    final tab       = ref.watch(currentTabProvider);
    final catId     = ref.watch(activeCategoryProvider);
    final booksAsync = ref.watch(activeBooksProvider);
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final isWishlist = tab == BookStatus.wishlist;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    isWishlist ? 'WISHLIST' : 'LIBRARY',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  const Spacer(),
                  // Toggle to the other view
                  IconButton(
                    icon: Icon(isWishlist
                        ? Icons.auto_stories_outlined
                        : Icons.bookmark_border_rounded),
                    tooltip: isWishlist ? 'Library' : 'Wishlist',
                    onPressed: () =>
                        _switchTab(isWishlist ? BookStatus.owned : BookStatus.wishlist),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Settings',
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Search ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => _debouncer.run(
                    () => ref.read(searchTextProvider.notifier).state = v),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '#Literature',
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            ref.read(searchTextProvider.notifier).state = '';
                          },
                        )
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Category tabs ─────────────────────────────────────────
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _CategoryTab(
                    label: 'All',
                    isActive: catId == null,
                    onTap: () =>
                        ref.read(activeCategoryProvider.notifier).state = null,
                    isDark: isDark,
                  ),
                  ...kCategories.map((cat) => _CategoryTab(
                        label: cat.name,
                        isActive: catId == cat.id,
                        onTap: () => ref
                            .read(activeCategoryProvider.notifier)
                            .state = cat.id,
                        isDark: isDark,
                      )),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Book grid ────────────────────────────────────────────
            Expanded(
              child: booksAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) =>
                    Center(child: Text('Error: $e')),
                data: (books) => books.isEmpty
                    ? _emptyState(catId, isWishlist)
                    : _Grid(
                        books: books,
                        isWishlist: isWishlist,
                        onTap: _openDetail,
                        onDelete: _softDelete,
                        onEdit: _openDetail,
                        onFavorite: (book) => ref
                            .read(bookRepositoryProvider)
                            .toggleFavorite(book.id, !book.isFavorite),
                        onMove: (book) => isWishlist
                            ? ref.read(bookRepositoryProvider).moveToOwned(book.id)
                            : ref.read(bookRepositoryProvider).moveToWishlist(book.id),
                        onReorder: (book, prev, next) => ref
                            .read(bookRepositoryProvider)
                            .reorder(book.id, prev, next),
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isWishlist
          ? FloatingActionButton(
              onPressed: _openAdd,
              tooltip: 'Add book',
              shape: const CircleBorder(),
              backgroundColor: isDark ? AppColors.dkInk : AppColors.ink,
              foregroundColor: isDark ? AppColors.dkPaper : AppColors.paper,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  Widget _emptyState(String? catId, bool isWishlist) {
    if (catId != null || _searchCtrl.text.isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        subtitle: 'Try a different search or category',
        action: TextButton(
          onPressed: () {
            _searchCtrl.clear();
            ref.read(searchTextProvider.notifier).state = '';
            ref.read(activeCategoryProvider.notifier).state = null;
          },
          child: const Text('Clear filters'),
        ),
      );
    }
    if (isWishlist) {
      return EmptyState(
        icon: Icons.bookmark_border_rounded,
        title: 'Wishlist is empty',
        subtitle: 'Books you want to read go here',
        action: FilledButton(onPressed: _openAdd, child: const Text('Add a book')),
      );
    }
    return EmptyState(
      icon: Icons.auto_stories_rounded,
      title: 'Your library is empty',
      subtitle: 'Start by adding your first book',
      action: FilledButton(onPressed: _openAdd, child: const Text('Add your first book')),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid — LayoutBuilder gives exact column width so covers are pixel-precise.
// ---------------------------------------------------------------------------

class _Grid extends StatelessWidget {
  final List<Book> books;
  final bool isWishlist;
  final void Function(Book) onTap;
  final void Function(Book) onDelete;
  final void Function(Book) onEdit;
  final void Function(Book) onFavorite;
  final void Function(Book) onMove;
  final void Function(Book book, double? prev, double? next) onReorder;

  const _Grid({
    required this.books,
    required this.isWishlist,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
    required this.onFavorite,
    required this.onMove,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    return MasonryGridView.count(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      crossAxisCount: 2,
      mainAxisSpacing: 20,
      crossAxisSpacing: 12,
      itemCount: books.length,
      itemBuilder: (_, i) {
        final book = books[i];
        return BookGridItem(
          key: ValueKey('${book.id}_$i'),
          book: book,
          isWishlist: isWishlist,
          onTap: () => onTap(book),
          onEdit: () => onEdit(book),
          onDelete: () => onDelete(book),
          onFavoriteToggle: isWishlist ? null : () => onFavorite(book),
          onMove: () => onMove(book),
          onMoveUp: isWishlist && i > 0
              ? () => onReorder(
                    book,
                    i > 1 ? books[i - 2].sortOrder : null,
                    books[i - 1].sortOrder,
                  )
              : null,
          onMoveDown: isWishlist && i < books.length - 1
              ? () => onReorder(
                    book,
                    books[i + 1].sortOrder,
                    i < books.length - 2 ? books[i + 2].sortOrder : null,
                  )
              : null,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Category tab
// ---------------------------------------------------------------------------

class _CategoryTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDark;

  const _CategoryTab({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final ink = isDark ? AppColors.dkInk : AppColors.ink;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                color: isActive ? ink : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
