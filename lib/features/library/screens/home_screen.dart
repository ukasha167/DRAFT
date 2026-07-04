import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/omnibox_parser.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../domain/models/book.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/omnibox_field.dart';
import '../../add_book/screens/add_book_sheet.dart';
import '../../book_detail/screens/book_detail_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../providers/library_providers.dart';
// ignore: unused_import — userCategoriesProvider used in Consumer below
import '../widgets/book_list_item.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 150));
  final _scrollKey = const PageStorageKey<String>('home_list');

  @override
  void initState() {
    super.initState();
    // Post-first-frame sweep: purge soft-deleted rows + orphaned cover files.
    // Runs off the cold-start critical path.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sweep());
  }

  Future<void> _sweep() async {
    final cutoff = DateTime.now()
        .subtract(const Duration(seconds: 60))
        .millisecondsSinceEpoch;
    await ref.read(bookRepositoryProvider).sweepExpiredDeletes(cutoff);
  }

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  void _onOmniboxChanged(String value) {
    _debouncer.run(() {
      ref.read(omniboxTextProvider.notifier).state = value;
    });
  }

  void _switchTab(BookStatus status) {
    // Clear :command tokens; preserve free-text and #tags.
    final raw = ref.read(omniboxTextProvider);
    final stripped = stripViewCommands(raw);
    ref.read(omniboxTextProvider.notifier).state = stripped;
    ref.read(currentTabProvider.notifier).state = status;
  }

  Future<void> _openAddSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddBookSheet(),
    );
  }

  void _softDelete(Book book) {
    ref.read(bookRepositoryProvider).softDelete(book.id);
    ref.read(lastDeletedProvider.notifier).state =
        (id: book.id, title: book.title);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${book.title}" deleted'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            final deleted = ref.read(lastDeletedProvider);
            if (deleted != null) {
              ref.read(bookRepositoryProvider).restore(deleted.id);
              ref.read(lastDeletedProvider.notifier).state = null;
            }
          },
        ),
      ),
    );
  }

  void _handleReorder(int oldIndex, int newIndex, List<Book> books) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;

    final reordered = [...books];
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);

    final prevOrder = newIndex > 0 ? reordered[newIndex - 1].sortOrder : null;
    final nextOrder = newIndex < reordered.length - 1
        ? reordered[newIndex + 1].sortOrder
        : null;

    ref.read(bookRepositoryProvider).reorder(item.id, prevOrder, nextOrder);
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(currentTabProvider);
    final omniboxText = ref.watch(omniboxTextProvider);
    final query = ref.watch(parsedQueryProvider);
    final booksAsync = ref.watch(activeBooksProvider);
    final isWishlist = tab == BookStatus.wishlist ||
        query.viewCommand == 'wishlist';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // App bar row
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Text('Library',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Settings',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ],
              ),
            ),

            // Omnibox
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Consumer(builder: (context, ref, _) {
                final cats =
                    ref.watch(userCategoriesProvider).valueOrNull ?? [];
                return OmniboxField(
                  initialValue: omniboxText,
                  onChanged: _onOmniboxChanged,
                  categories: cats,
                );
              }),
            ),

            // Owned / Wishlist toggle
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SegmentedButton<BookStatus>(
                segments: const [
                  ButtonSegment(
                    value: BookStatus.owned,
                    label: Text('Owned'),
                    icon: Icon(Icons.library_books_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: BookStatus.wishlist,
                    label: Text('Wishlist'),
                    icon: Icon(Icons.bookmark_border_rounded, size: 18),
                  ),
                ],
                selected: {tab},
                onSelectionChanged: (s) => _switchTab(s.first),
                style: ButtonStyle(
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(
                        fontFamily: 'Manrope', fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),

            // Book list
            Expanded(
              child: booksAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (books) {
                  if (books.isEmpty) {
                    return _buildEmptyState(query, isWishlist);
                  }

                  if (isWishlist) {
                    return ReorderableListView.builder(
                      key: _scrollKey,
                      buildDefaultDragHandles: false, // handle-only dragging
                      padding: const EdgeInsets.only(bottom: 96),
                      onReorder: (o, n) => _handleReorder(o, n, books),
                      itemCount: books.length,
                      itemBuilder: (context, index) {
                        final book = books[index];
                        return BookListItem(
                          key: ValueKey(book.id),
                          book: book,
                          isWishlist: true,
                          dragHandle: ReorderableDragStartListener(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                Icons.drag_handle_rounded,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppColors.subtleDark
                                    : AppColors.subtleLight,
                              ),
                            ),
                          ),
                          onTap: () => _openDetail(context, book),
                          onDelete: () => _softDelete(book),
                          onEdit: () => _openDetail(context, book),
                          onMove: () => ref
                              .read(bookRepositoryProvider)
                              .moveToOwned(book.id),
                          onMoveUp: index > 0
                              ? () => _handleReorder(index, index - 1, books)
                              : null,
                          onMoveDown: index < books.length - 1
                              ? () => _handleReorder(index, index + 2, books)
                              : null,
                        );
                      },
                    );
                  }

                  // Owned list — fixed itemExtent for zero per-item layout cost.
                  return ListView.builder(
                    key: _scrollKey,
                    padding: const EdgeInsets.only(bottom: 96),
                    itemCount: books.length,
                    itemExtent: kBookListItemHeight,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      return BookListItem(
                        key: ValueKey(book.id),
                        book: book,
                        isWishlist: false,
                        onTap: () => _openDetail(context, book),
                        onDelete: () => _softDelete(book),
                        onEdit: () => _openDetail(context, book),
                        onFavoriteToggle: () => ref
                            .read(bookRepositoryProvider)
                            .toggleFavorite(book.id, !book.isFavorite),
                        onMove: () => ref
                            .read(bookRepositoryProvider)
                            .moveToWishlist(book.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        tooltip: 'Add book',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildEmptyState(ParsedQuery query, bool isWishlist) {
    if (query.hasFilters) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        subtitle: 'Try adjusting your search or filters',
      );
    }
    if (isWishlist) {
      return EmptyState(
        icon: Icons.bookmark_border_rounded,
        title: 'Wishlist is empty',
        subtitle: 'Add books you want to read someday',
        action: FilledButton.tonal(
          onPressed: _openAddSheet,
          child: const Text('Add a book'),
        ),
      );
    }
    return EmptyState(
      icon: Icons.auto_stories_rounded,
      title: 'Your library is empty',
      subtitle: 'Add your first book to get started',
      action: FilledButton(
        onPressed: _openAddSheet,
        child: const Text('Add your first book'),
      ),
    );
  }

  void _openDetail(BuildContext context, Book book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookDetailScreen(bookId: book.id)),
    );
  }
}
