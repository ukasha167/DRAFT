import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/theme/app_theme.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../domain/models/book.dart';
import '../../add_book/widgets/book_form_widget.dart';
import '../providers/book_detail_providers.dart';

class BookDetailScreen extends ConsumerWidget {
  final String bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookDetailProvider(bookId));
    return async.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (book) {
        if (book == null) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => Navigator.maybePop(context));
          return const Scaffold(
              body: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        return _DetailView(book: book);
      },
    );
  }
}

class _DetailView extends ConsumerWidget {
  final Book book;
  const _DetailView({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo   = ref.read(bookRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink    = isDark ? AppColors.dkInk : AppColors.ink;
    final paper  = isDark ? AppColors.dkPaper : AppColors.paper;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Cover + nav overlay ─────────────────────────────────
          SliverToBoxAdapter(
            child: Stack(
              children: [
                // Cover: full width, capped height, BoxFit.cover.
                // Alignment.topCenter ensures title of the cover shows.
                SizedBox(
                  width: double.infinity,
                  height: 310,
                  child: _FullCover(book: book),
                ),
                // Nav row over the cover
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        _NavButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.pop(context),
                          paper: paper,
                        ),
                        const Spacer(),
                        // Favourite
                        _NavButton(
                          icon: book.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: book.isFavorite ? AppColors.blood : null,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            repo.toggleFavorite(book.id, !book.isFavorite);
                          },
                          paper: paper,
                        ),
                        _NavButton(
                          icon: Icons.more_vert_rounded,
                          onTap: () => _showMenu(context, ref),
                          paper: paper,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Content ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title — all caps, heavy
                  Text(
                    book.title.toUpperCase(),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: ink,
                          letterSpacing: -0.3,
                        ),
                  ),
                  const SizedBox(height: 6),

                  // Author
                  if (book.author != null)
                    Text(book.author!,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(color: AppColors.muted)),

                  const SizedBox(height: 14),

                  // Categories as dot-separated text
                  if (book.categories.isNotEmpty)
                    Text(
                      book.categories.map((c) => c.name).join(' · '),
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: AppColors.muted, fontSize: 12),
                    ),

                  const SizedBox(height: 20),

                  // Reading status — owned only
                  if (book.isOwned) ...[
                    _SectionLabel('READING STATUS', context),
                    const SizedBox(height: 10),
                    Row(
                      children: ReadingStatus.values.map((s) {
                        final active = book.readingStatus == s;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () => repo.setReadingStatus(
                                book.id, active ? null : s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: active ? ink : Colors.transparent,
                                border: Border.all(
                                    color: active ? ink : AppColors.muted,
                                    width: 1.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                s.label,
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: active ? paper : AppColors.muted,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Summary
                  if (book.summary?.isNotEmpty == true) ...[
                    _SectionLabel('SUMMARY', context),
                    const SizedBox(height: 10),
                    Text(book.summary!,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(height: 1.6)),
                    const SizedBox(height: 28),
                  ],

                  // Primary action
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        if (book.isOwned) {
                          repo.moveToWishlist(book.id);
                        } else {
                          repo.moveToOwned(book.id);
                        }
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                        backgroundColor: ink,
                        foregroundColor: paper,
                      ),
                      child: Text(
                        book.isOwned
                            ? 'MOVE TO WISHLIST'
                            : 'MOVE TO LIBRARY',
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context, WidgetRef ref) {
    final repo = ref.read(bookRepositoryProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36, height: 3,
              decoration: BoxDecoration(
                  color: AppColors.muted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit', style: TextStyle(fontFamily: 'Manrope')),
              onTap: () {
                Navigator.pop(context);
                _openEdit(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.blood),
              title: const Text('Delete',
                  style: TextStyle(fontFamily: 'Manrope', color: AppColors.blood)),
              onTap: () {
                Navigator.pop(context);
                repo.softDelete(book.id);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openEdit(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditSheet(book: book),
    );
  }
}

class _EditSheet extends ConsumerWidget {
  final Book book;
  const _EditSheet({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(width: 36, height: 3,
              decoration: BoxDecoration(
                color: AppColors.muted.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              children: [
                Text('Edit book',
                    style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
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
                required title, author, isbn, summary,
                required categoryIds,
              }) async {
                await ref.read(bookRepositoryProvider).updateBook(
                    id: book.id, title: title, author: author,
                    isbn: isbn, summary: summary, categoryIds: categoryIds);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-width cover (detail screen)
// ---------------------------------------------------------------------------

class _FullCover extends ConsumerWidget {
  final Book book;
  const _FullCover({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsDir = ref.watch(docsDirProvider);
    final stored  = book.coverFullPath ?? book.coverThumbPath;

    if (stored != null) {
      final resolved =
          p.isAbsolute(stored) ? stored : p.join(docsDir, stored);
      if (File(resolved).existsSync()) {
        return Image.file(
          File(resolved),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter, // keep title of cover in frame
        );
      }
    }
    // Placeholder gradient
    final hue =
        (book.initials.codeUnits.fold(0, (a, b) => a + b) * 47) % 360;
    final color = HSLColor.fromAHSL(1, hue.toDouble(), 0.35, 0.38).toColor();
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Text(book.initials,
          style: const TextStyle(fontFamily: 'Manrope',
              fontSize: 56, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}

// Floating nav button overlaid on the cover
class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Color paper;
  const _NavButton({required this.icon, required this.onTap,
      required this.paper, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: paper.withOpacity(0.85),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20,
            color: color ?? (paper == AppColors.paper ? AppColors.ink : AppColors.dkInk)),
      ),
    );
  }
}

Widget _SectionLabel(String text, BuildContext context) {
  return Text(text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.5,
            color: AppColors.muted,
            fontWeight: FontWeight.w700,
          ));
}
