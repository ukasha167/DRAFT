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
    return ref.watch(bookDetailProvider(bookId)).when(
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
        return _Detail(book: book);
      },
    );
  }
}

class _Detail extends ConsumerWidget {
  final Book book;
  const _Detail({required this.book});

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
                SizedBox(
                  width: double.infinity,
                  height: 310,
                  child: _FullCover(book: book),
                ),
                // Nav controls overlaid on cover
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        _CircleButton(
                          icon: Icons.arrow_back_rounded,
                          paper: paper, ink: ink,
                          onTap: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        // Favourite
                        _CircleButton(
                          icon: book.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          iconColor: book.isFavorite ? AppColors.blood : null,
                          paper: paper, ink: ink,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            repo.toggleFavorite(book.id, !book.isFavorite);
                          },
                        ),
                        // Menu — PopupMenuButton opens near the button, not bottom
                        _MenuButton(book: book, paper: paper, ink: ink),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Content ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: ink,
                      letterSpacing: -0.3,
                      height: 1.15,
                    ),
                  ),
                  if (book.author != null) ...[
                    const SizedBox(height: 6),
                    Text(book.author!,
                        style: TextStyle(
                          fontFamily: 'Manrope', fontSize: 16,
                          fontWeight: FontWeight.w500, color: AppColors.muted,
                        )),
                  ],

                  if (book.categories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      book.categories.map((c) => c.name).join(' · '),
                      style: const TextStyle(
                        fontFamily: 'Manrope', fontSize: 12,
                        fontWeight: FontWeight.w600, color: AppColors.muted,
                      ),
                    ),
                  ],

                  if (book.isOwned) ...[
                    const SizedBox(height: 24),
                    Text('READING STATUS',
                        style: TextStyle(
                          fontFamily: 'Manrope', fontSize: 11,
                          fontWeight: FontWeight.w700, color: AppColors.muted,
                          letterSpacing: 1.5,
                        )),
                    const SizedBox(height: 10),
                    Row(
                      children: ReadingStatus.values.map((s) {
                        final active = book.readingStatus == s;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () =>
                                repo.setReadingStatus(book.id, active ? null : s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: active ? ink : Colors.transparent,
                                border: Border.all(
                                    color: active ? ink : AppColors.muted.withOpacity(0.5),
                                    width: 1.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(s.label,
                                  style: TextStyle(
                                    fontFamily: 'Manrope', fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: active ? paper : AppColors.muted,
                                  )),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  if (book.summary?.isNotEmpty == true) ...[
                    const SizedBox(height: 24),
                    Text('SUMMARY',
                        style: TextStyle(
                          fontFamily: 'Manrope', fontSize: 11,
                          fontWeight: FontWeight.w700, color: AppColors.muted,
                          letterSpacing: 1.5,
                        )),
                    const SizedBox(height: 10),
                    Text(book.summary!,
                        style: TextStyle(
                          fontFamily: 'Manrope', fontSize: 14,
                          fontWeight: FontWeight.w400, color: ink, height: 1.65,
                        )),
                  ],

                  const SizedBox(height: 32),

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
                            borderRadius: BorderRadius.circular(10)),
                        backgroundColor: ink,
                        foregroundColor: paper,
                      ),
                      child: Text(
                        book.isOwned ? 'MOVE TO WISHLIST' : 'MOVE TO LIBRARY',
                        style: const TextStyle(
                          fontFamily: 'Manrope', fontWeight: FontWeight.w800,
                          fontSize: 13, letterSpacing: 0.8,
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
}

// Hamburger — PopupMenuButton opens the menu near the button, not bottom sheet.
class _MenuButton extends ConsumerWidget {
  final Book book;
  final Color paper;
  final Color ink;
  const _MenuButton({required this.book, required this.paper, required this.ink});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(bookRepositoryProvider);
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'edit': _openEdit(context, ref);
          case 'delete':
            repo.softDelete(book.id);
            Navigator.pop(context);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(children: [
            const Icon(Icons.edit_outlined, size: 17),
            const SizedBox(width: 12),
            Text('Edit', style: TextStyle(fontFamily: 'Manrope', fontSize: 14,
                fontWeight: FontWeight.w500, color: ink)),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            const Icon(Icons.delete_outline_rounded, size: 17, color: AppColors.blood),
            const SizedBox(width: 12),
            const Text('Delete', style: TextStyle(fontFamily: 'Manrope', fontSize: 14,
                fontWeight: FontWeight.w500, color: AppColors.blood)),
          ]),
        ),
      ],
      // Style the trigger button to match the nav circle buttons
      child: Container(
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: paper.withOpacity(0.85),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.more_vert_rounded, size: 20, color: ink),
      ),
    );
  }

  void _openEdit(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(book: book),
    );
  }
}

class _EditSheet extends ConsumerWidget {
  final Book book;
  const _EditSheet({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.dkPaper : AppColors.paper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(width: 36, height: 3,
              decoration: BoxDecoration(color: AppColors.muted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(children: [
              Text('Edit book',
                  style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Flexible(
            child: BookFormWidget(
              initialTitle: book.title, initialAuthor: book.author,
              initialIsbn: book.isbn, initialSummary: book.summary,
              initialCategories: book.categories, isEditing: true,
              onSave: ({required title, author, isbn, summary,
                  required categoryIds}) async {
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

// Full cover image for the detail header
class _FullCover extends ConsumerWidget {
  final Book book;
  const _FullCover({required this.book});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsDir = ref.watch(docsDirProvider);
    final stored  = book.coverFullPath ?? book.coverThumbPath;
    if (stored != null) {
      final resolved = p.isAbsolute(stored) ? stored : p.join(docsDir, stored);
      if (File(resolved).existsSync()) {
        return Image.file(File(resolved),
            width: double.infinity, height: double.infinity,
            fit: BoxFit.cover, alignment: Alignment.topCenter);
      }
    }
    final hue = (book.initials.codeUnits.fold(0, (a, b) => a + b) * 47) % 360;
    final color = HSLColor.fromAHSL(1, hue.toDouble(), 0.35, 0.38).toColor();
    return Container(color: color, alignment: Alignment.center,
        child: Text(book.initials,
            style: const TextStyle(fontFamily: 'Manrope', fontSize: 56,
                fontWeight: FontWeight.w800, color: Colors.white)));
  }
}

// Circle button overlaid on the cover
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color paper, ink;
  const _CircleButton({required this.icon, required this.onTap,
      required this.paper, required this.ink, this.iconColor});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: paper.withOpacity(0.85), shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: iconColor ?? ink),
      ),
    );
  }
}
