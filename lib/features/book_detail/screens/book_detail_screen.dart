import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../domain/models/book.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/category_chip.dart';
import '../../add_book/widgets/book_form_widget.dart';
import '../providers/book_detail_providers.dart';

class BookDetailScreen extends ConsumerWidget {
  final String bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookDetailProvider(bookId));

    return bookAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Error: $e'))),
      data: (book) {
        if (book == null) {
          // Book was deleted — pop automatically.
          WidgetsBinding.instance
              .addPostFrameCallback((_) => Navigator.maybePop(context));
          return const Scaffold(
              body: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        return _BookDetailView(book: book);
      },
    );
  }
}

class _BookDetailView extends ConsumerWidget {
  final Book book;
  const _BookDetailView({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(bookRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtle = isDark ? AppColors.subtleDark : AppColors.subtleLight;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Collapsing app bar with full-res cover
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: () => _openEdit(context, ref),
              ),
              PopupMenuButton<String>(
                onSelected: (v) =>
                    _handleMenuAction(v, context, ref),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'move',
                    child: Text(book.isOwned
                        ? 'Move to Wishlist'
                        : 'Move to Owned'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  BookCover(
                    thumbPath: book.coverThumbPath,
                    fullPath: book.coverFullPath,
                    initials: book.initials,
                    width: MediaQuery.sizeOf(context).width,
                    useFullRes: true,
                  ),
                  // Gradient so text above is readable
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                        stops: [0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(book.title,
                      style: Theme.of(context).textTheme.headlineMedium),
                  if (book.author != null) ...[
                    const SizedBox(height: 4),
                    Text(book.author!,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: subtle)),
                  ],
                  if (book.isbn != null) ...[
                    const SizedBox(height: 4),
                    Text('ISBN: ${book.isbn}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: subtle)),
                  ],

                  const SizedBox(height: 20),

                  // Owned-only controls
                  if (book.isOwned) ...[
                    // Reading status
                    _SectionTitle('Reading status'),
                    const SizedBox(height: 8),
                    SegmentedButton<ReadingStatus?>(
                      segments: const [
                        ButtonSegment(
                          value: ReadingStatus.notStarted,
                          label: Text('Not started'),
                        ),
                        ButtonSegment(
                          value: ReadingStatus.reading,
                          label: Text('Reading'),
                        ),
                        ButtonSegment(
                          value: ReadingStatus.finished,
                          label: Text('Finished'),
                        ),
                      ],
                      selected: {book.readingStatus},
                      onSelectionChanged: (s) =>
                          repo.setReadingStatus(book.id, s.first),
                    ),
                    const SizedBox(height: 20),

                    // Favorite
                    Row(
                      children: [
                        const _SectionTitle('Favorite'),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            book.isFavorite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: book.isFavorite
                                ? AppColors.accent
                                : subtle,
                            size: 28,
                          ),
                          tooltip: book.isFavorite
                              ? 'Remove favorite'
                              : 'Add to favorites',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            repo.toggleFavorite(
                                book.id, !book.isFavorite);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Categories
                  if (book.categories.isNotEmpty) ...[
                    _SectionTitle('Categories'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: book.categories
                          .map((c) => CategoryChip(category: c))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Summary
                  if (book.summary?.isNotEmpty == true) ...[
                    _SectionTitle('Summary'),
                    const SizedBox(height: 8),
                    Text(book.summary!,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openEdit(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
              child: Row(
                children: [
                  Text('Edit book',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: BookFormWidget(
                initialTitle: book.title,
                initialAuthor: book.author,
                initialIsbn: book.isbn,
                initialSummary: book.summary,
                initialCategories: book.categories,
                isEditing: true,
                onSave: ({
                  required String title,
                  String? author,
                  String? isbn,
                  String? summary,
                  required List<String> categoryIds,
                }) async {
                  await ref.read(bookRepositoryProvider).updateBook(
                        id: book.id,
                        title: title,
                        author: author,
                        isbn: isbn,
                        summary: summary,
                        categoryIds: categoryIds,
                      );
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(
      String action, BuildContext context, WidgetRef ref) {
    final repo = ref.read(bookRepositoryProvider);
    switch (action) {
      case 'move':
        if (book.isOwned) {
          repo.moveToWishlist(book.id);
        } else {
          repo.moveToOwned(book.id);
        }
        Navigator.pop(context);
      case 'delete':
        repo.softDelete(book.id);
        Navigator.pop(context);
        // Snackbar is shown from HomeScreen when it observes the deletion.
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleSmall);
  }
}
