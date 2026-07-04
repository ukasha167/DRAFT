import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/book.dart';
import '../../../shared/widgets/book_cover.dart';
import '../../../shared/widgets/category_chip.dart';

/// Fixed-height list row. [itemExtent] in ListView.builder is set to match
/// this so Flutter skips per-item layout passes entirely.
// CHANGED: Increased from 72.0 to 88.0 to account for title, author, and category chips
const double kBookListItemHeight = 88.0;

class BookListItem extends StatelessWidget {
  final Book book;
  final bool isWishlist;

  // Callbacks
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onMove;
  final VoidCallback? onEdit;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  /// When non-null, renders a drag handle and wraps it in this widget
  /// (caller passes ReorderableDragStartListener).
  final Widget? dragHandle;

  const BookListItem({
    super.key,
    required this.book,
    required this.isWishlist,
    this.onTap,
    this.onDelete,
    this.onFavoriteToggle,
    this.onMove,
    this.onEdit,
    this.onMoveUp,
    this.onMoveDown,
    this.dragHandle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kBookListItemHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: () => _showActionSheet(context),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Cover thumbnail — decodes at display size only.
                BookCover(
                  thumbPath: book.coverThumbPath,
                  initials: book.initials,
                  width: 34,
                ),
                const SizedBox(width: 14),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        book.title,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (book.author != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          book.author!,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (book.categories.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: book.categories
                                .take(4)
                                .map((c) => Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: CategoryChip(category: c),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                if (!isWishlist) ...[
                  if (book.isFavorite)
                    const Icon(Icons.star_rounded,
                        color: AppColors.accent, size: 18),
                  if (book.readingStatus == ReadingStatus.reading)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.menu_book_rounded,
                          color: AppColors.accent, size: 18),
                    ),
                  if (book.readingStatus == ReadingStatus.finished)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.check_circle_outline_rounded,
                          color: AppColors.success, size: 18),
                    ),
                ],

                // Wishlist: drag handle is the ONLY reorder trigger.
                // Long-press on the row opens the action sheet.
                if (isWishlist && dragHandle != null)
                  Semantics(
                    label: 'Drag to reorder',
                    child: dragHandle!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(book.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            _ActionTile(
              icon: Icons.edit_outlined,
              label: 'Edit',
              onTap: () { Navigator.pop(context); onEdit?.call(); },
            ),
            if (!isWishlist)
              _ActionTile(
                icon: book.isFavorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                label: book.isFavorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                  onFavoriteToggle?.call();
                },
              ),
            _ActionTile(
              icon: isWishlist
                  ? Icons.library_add_check_outlined
                  : Icons.bookmark_border_rounded,
              label: isWishlist ? 'Move to Owned' : 'Move to Wishlist',
              onTap: () { Navigator.pop(context); onMove?.call(); },
            ),
            // Accessible reorder (spec §12) — Wishlist only.
            if (isWishlist) ...[
              _ActionTile(
                icon: Icons.arrow_upward_rounded,
                label: 'Move up',
                onTap: () { Navigator.pop(context); onMoveUp?.call(); },
              ),
              _ActionTile(
                icon: Icons.arrow_downward_rounded,
                label: 'Move down',
                onTap: () { Navigator.pop(context); onMoveDown?.call(); },
              ),
            ],
            const Divider(height: 1),
            _ActionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: AppColors.error,
              onTap: () {
                Navigator.pop(context);
                HapticFeedback.heavyImpact();
                onDelete?.call();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: c, size: 22),
      title:
          Text(label, style: TextStyle(fontFamily: 'Manrope', color: c)),
      dense: true,
      onTap: onTap,
    );
  }
}
