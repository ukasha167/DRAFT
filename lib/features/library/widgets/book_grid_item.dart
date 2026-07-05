import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/theme/app_theme.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../domain/models/book.dart';

class BookGridItem extends ConsumerWidget {
  final Book book;
  final bool isWishlist;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onMove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const BookGridItem({
    super.key,
    required this.book,
    required this.isWishlist,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onFavoriteToggle,
    this.onMove,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      onLongPressStart: (details) {
        HapticFeedback.mediumImpact();
        _showContextMenu(context, details.globalPosition, isDark);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover ──────────────────────────────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _Cover(book: book),
                ),
                if (book.isFavorite)
                  Positioned(
                    bottom: 16, right: -12,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.dkPaper : AppColors.paper),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_rounded,
                          color: AppColors.blood, size: 16),
                    ),
                  ),
              ],
            ),

            // ── Title + Author ─────────────────────────────────────
            const SizedBox(height: 9),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(

                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.dkInk : AppColors.ink,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              book.author ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(

                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showContextMenu(BuildContext context, Offset position, bool isDark) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final result = await showMenu<_Action>(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 12,
      color: isDark ? AppColors.dkPaper : AppColors.paper,
      position: RelativeRect.fromRect(
        // 1×1 rect at the finger position — Flutter auto-flips if near edges
        Rect.fromLTWH(position.dx, position.dy, 1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        _menuItem(_Action.edit, Icons.edit_outlined, 'Edit'),
        if (!isWishlist)
          _menuItem(
            _Action.favorite,
            book.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            book.isFavorite ? 'Remove favourite' : 'Add favourite',
          ),
        _menuItem(
          _Action.move,
          isWishlist ? Icons.library_add_check_outlined : Icons.bookmark_border_rounded,
          isWishlist ? 'Move to Library' : 'Move to Wishlist',
        ),
        if (isWishlist && onMoveUp != null)
          _menuItem(_Action.up, Icons.arrow_upward_rounded, 'Move up'),
        if (isWishlist && onMoveDown != null)
          _menuItem(_Action.down, Icons.arrow_downward_rounded, 'Move down'),
        const PopupMenuDivider(height: 1),
        _menuItem(_Action.delete, Icons.delete_outline_rounded, 'Delete',
            isDestructive: true),
      ],
    );

    if (result == null) return;
    switch (result) {
      case _Action.edit:     onEdit?.call();
      case _Action.favorite: onFavoriteToggle?.call();
      case _Action.move:     onMove?.call();
      case _Action.up:       onMoveUp?.call();
      case _Action.down:     onMoveDown?.call();
      case _Action.delete:
        HapticFeedback.heavyImpact();
        onDelete?.call();
    }
  }

  PopupMenuItem<_Action> _menuItem(
    _Action action, IconData icon, String label, {bool isDestructive = false}) {
    final color = isDestructive ? AppColors.blood : null;
    return PopupMenuItem<_Action>(
      value: action,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 16),
          Text(label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: -0.2,
              )),
        ],
      ),
    );
  }
}

enum _Action { edit, favorite, move, up, down, delete }

// ---------------------------------------------------------------------------
// Cover
// ---------------------------------------------------------------------------

class _Cover extends ConsumerWidget {
  final Book book;
  const _Cover({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsDir = ref.watch(docsDirProvider);
    final stored  = book.coverThumbPath;

    if (stored != null) {
      final resolved = p.isAbsolute(stored) ? stored : p.join(docsDir, stored);
      if (File(resolved).existsSync()) {
        return Image.file(
          File(resolved),
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => _Placeholder(book: book),
        );
      }
    }
    return _Placeholder(book: book);
  }
}

class _Placeholder extends StatelessWidget {
  final Book book;
  const _Placeholder({required this.book});

  @override
  Widget build(BuildContext context) {
    final hue = (book.initials.codeUnits.fold(0, (a, b) => a + b) * 47) % 360;
    final color = HSLColor.fromAHSL(1, hue.toDouble(), 0.35, 0.40).toColor();
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: Container(
        color: color,
        alignment: Alignment.center,
        child: Text(book.initials,
            style: const TextStyle(fontSize: 22,
                fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
      ),
    );
  }
}
