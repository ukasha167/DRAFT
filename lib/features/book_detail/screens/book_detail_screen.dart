import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/modern_context_menu.dart';
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
      body: Stack(
        children: [
          // ShaderMask creates a smooth gradient fade toward the bottom
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0.0, 0.72, 1.0],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: CustomScrollView(
              slivers: [
                // ── Cover + nav overlay ─────────────────────────────────
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: MediaQuery.of(context).size.height * 0.60,
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
                              if (book.isOwned)
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
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title.toUpperCase(),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: ink,
                            letterSpacing: 1.5,
                            height: 1.15,
                          ),
                        ),
                        if (book.author != null) ...[
                          const SizedBox(height: 6),
                          Text(book.author!,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500, color: AppColors.muted,
                              )),
                        ],

                        if (book.categories.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'CATEGORIES: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: ink,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                TextSpan(text: book.categories.map((c) => c.name).join(', ')),
                              ],
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500, color: AppColors.muted,
                            ),
                          ),
                        ],

                        if (book.summary?.isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          Text(
                            'SUMMARY',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: ink,
                              letterSpacing: 1.8,
                            ),
                          ),
                          MarkdownBody(
                            data: book.summary!
                                .replaceAll('*', '')
                                .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n\n')
                                .replaceAll(RegExp(r'</?(b|i)>', caseSensitive: false), ''),
                            extensionSet: md.ExtensionSet.gitHubFlavored,
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400, color: ink, height: 1.65,
                              ),
                              strong: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800, color: ink, height: 1.65,
                              ),
                              em: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400, fontStyle: FontStyle.italic, color: ink, height: 1.65,
                              ),
                            ),
                          ),
                        ],

                        if (book.isbn?.isNotEmpty == true) ...[
                          const SizedBox(height: 16),
                          Text.rich(
                             TextSpan(
                              children: [
                                 TextSpan(
                                  text: 'ISBN: ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: ink,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                                TextSpan(
                                  text: book.isbn!,
                                  style:  TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: ink,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ]

                            )
                          ),
                        ],

                        if (book.isOwned) ...[
                          const SizedBox(height: 12),
                          Text('READING STATUS',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: ink,
                                letterSpacing: 1.2,
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
                                          color: active
                                              ? ink
                                              : AppColors.muted.withOpacity(0.5),
                                          width: 1.5),
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                    child: Text(s.label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: active ? paper : AppColors.muted,
                                        )),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Button floats above the fade — no blur, just clean
          Positioned(
            left: 20, right: 20, bottom: 36,
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
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40)),
                backgroundColor: ink,
                foregroundColor: paper,
              ),
              child: Text(
                book.isOwned ? 'MOVE TO WISHLIST' : 'MOVE TO LIBRARY',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14, letterSpacing: 0.8,
                ),
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

  void _showModernMenu(BuildContext context, WidgetRef ref) {
    final repo = ref.read(bookRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final glassColor = isDark
        ? const Color(0x991C1C1E)
        : const Color(0xB2FFFFFF);

    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final buttonSize = renderBox.size;

    final screenWidth = MediaQuery.of(context).size.width;
    final rightPadding = screenWidth - (offset.dx + buttonSize.width);
    final topPadding = offset.dy + buttonSize.height + 8;

    showModernContextMenu(
      context: context,
      // Pass the top right corner of the menu placement area
      position: Offset(screenWidth - rightPadding, topPadding),
      menuWidth: 180,
      menuHeight: 100, // Roughly 2 items + divider
      glassColor: glassColor,
      borderColor: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
      originAlignment: Alignment.topRight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMenuItem('Edit', Icons.edit_outlined, ink, () {
            Navigator.pop(context);
            _openEdit(context, ref);
          }),
          Container(height: 0.5, color: AppColors.muted.withOpacity(0.3)),
          _buildMenuItem('Delete', Icons.delete_outline_rounded, AppColors.blood, () {
            Navigator.pop(context);
            repo.softDelete(book.id);
          }),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w400, color: color, letterSpacing: -0.4)),
            Icon(icon, size: 20, color: color),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showModernMenu(context, ref),
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

class _EditSheet extends ConsumerStatefulWidget {
  final Book book;
  const _EditSheet({required this.book});

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  String? _localCoverPath;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetColor = isDark ? AppColors.dkPaper : AppColors.paper;

    // ScaffoldMessenger wrapper ensures SnackBars from BookFormWidget
    // appear inside the sheet overlay, not behind it.
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            color: sheetColor,
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
                  initialTitle: widget.book.title,
                  initialAuthor: widget.book.author,
                  initialIsbn: widget.book.isbn,
                  initialSummary: widget.book.summary,
                  initialCategories: widget.book.categories,
                  isEditing: true,
                  onCoverChanged: (path) => setState(() => _localCoverPath = path),
                  onSave: ({required title, author, isbn, summary,
                      required categoryIds}) async {
                    await ref.read(bookRepositoryProvider).updateBook(
                        id: widget.book.id, title: title, author: author,
                        isbn: isbn, summary: summary,
                        localCoverPath: _localCoverPath,
                        categoryIds: categoryIds);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.dkCream : AppColors.cream;
    final docsDir = ref.watch(docsDirProvider);
    final stored  = book.coverFullPath ?? book.coverThumbPath;

    Widget coverContent;
    bool found = false;

    if (stored != null) {
      final resolved = p.isAbsolute(stored) ? stored : p.join(docsDir, stored);
      if (File(resolved).existsSync()) {
        coverContent = Image.file(File(resolved),
            width: double.infinity, height: double.infinity,
            fit: BoxFit.cover, alignment: Alignment.topCenter);
        found = true;
      } else {
        coverContent = const SizedBox();
      }
    } else {
      coverContent = const SizedBox();
    }

    if (!found) {
      final hue = (book.initials.codeUnits.fold(0, (a, b) => a + b) * 47) % 360;
      final color = HSLColor.fromAHSL(1, hue.toDouble(), 0.35, 0.38).toColor();
      coverContent = Container(color: color, alignment: Alignment.center,
          child: Text(book.initials,
              style: const TextStyle(fontSize: 56,
                  fontWeight: FontWeight.w800, color: Colors.white)));
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: bgColor,
      padding: const EdgeInsets.fromLTRB(70, 70, 70, 30),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: coverContent,
        ),
      ),
    );
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
