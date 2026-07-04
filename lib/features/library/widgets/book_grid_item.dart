import 'dart:io';
import 'dart:math' as math;

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
      onLongPress: () {
        HapticFeedback.mediumImpact();
        _showActionSheet(context);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cover ──────────────────────────────────────────────────
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Cover(book: book),
                  // Favorite heart badge
                  if (book.isFavorite)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.dkPaper.withOpacity(0.85)
                              : AppColors.paper.withOpacity(0.85),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: AppColors.blood,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Title + Author ─────────────────────────────────────────
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            book.author ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36, height: 3,
              decoration: BoxDecoration(
                color: AppColors.muted.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                book.title,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            _Item(icon: Icons.edit_outlined,       label: 'Edit',
                onTap: () { Navigator.pop(context); onEdit?.call(); }),
            if (!isWishlist)
              _Item(
                icon: book.isFavorite
                    ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                label: book.isFavorite ? 'Remove from favourites' : 'Add to favourites',
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                  onFavoriteToggle?.call();
                },
              ),
            _Item(
              icon: isWishlist
                  ? Icons.library_add_check_outlined
                  : Icons.bookmark_border_rounded,
              label: isWishlist ? 'Move to Library' : 'Move to Wishlist',
              onTap: () { Navigator.pop(context); onMove?.call(); },
            ),
            // Accessible reorder — primary mechanism in grid (no drag).
            if (isWishlist && onMoveUp != null)
              _Item(icon: Icons.arrow_upward_rounded, label: 'Move up',
                  onTap: () { Navigator.pop(context); onMoveUp?.call(); }),
            if (isWishlist && onMoveDown != null)
              _Item(icon: Icons.arrow_downward_rounded, label: 'Move down',
                  onTap: () { Navigator.pop(context); onMoveDown?.call(); }),
            const Divider(height: 1),
            _Item(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: AppColors.blood,
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

// ---------------------------------------------------------------------------
// Cover renderer — fills its parent via StackFit.expand, BoxFit.cover.
// Handles relative / legacy-absolute path resolution and shows initials on miss.
// ---------------------------------------------------------------------------

class _Cover extends ConsumerWidget {
  final Book book;
  const _Cover({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsDir = ref.watch(docsDirProvider);
    final stored  = book.coverThumbPath;

    if (stored != null) {
      final resolved =
          p.isAbsolute(stored) ? stored : p.join(docsDir, stored);
      if (File(resolved).existsSync()) {
        return Image.file(
          File(resolved),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _Initials(book: book),
        );
      }
    }
    return _Initials(book: book);
  }
}

class _Initials extends StatelessWidget {
  final Book book;
  const _Initials({required this.book});

  @override
  Widget build(BuildContext context) {
    final hue =
        (book.initials.codeUnits.fold(0, (a, b) => a + b) * 47) % 360;
    final color =
        HSLColor.fromAHSL(1, hue.toDouble(), 0.35, 0.40).toColor();
    final fontSize = 22.0;

    return Container(
      color: color,
      alignment: Alignment.center,
      child: Text(
        book.initials,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _Item({required this.icon, required this.label,
      required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: c, size: 20),
      title: Text(label,
          style: TextStyle(fontFamily: 'Manrope', color: c, fontSize: 14)),
      onTap: onTap,
    );
  }
}
