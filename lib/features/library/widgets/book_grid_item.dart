import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/modern_context_menu.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../domain/models/book.dart';
import '../../../core/utils/color_utils.dart';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: getWashedAmbientColor(book.dominantColor, isDark) ??
                      (isDark ? draftSurfaceDark : draftSurface),
                  border: Border.all(
                    color: isDark ? draftBorderDark : draftBorder,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.14),
                        offset: const Offset(2, 4),
                        blurRadius: 10,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: _Cover(book: book),
                  ),
                ),
              ),
              if (book.isFavorite)
                Positioned(
                  bottom: -8,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? draftBackgroundDark : draftBackground,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: draftRed,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: loraCardTitle.copyWith(
              color: isDark ? draftInkDark : draftInk,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            book.author ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: loraCardAuthor.copyWith(
              color: isDark ? draftInkSecondaryDark : draftInkSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    Offset position,
    bool isDark,
  ) async {
    final glassColor = isDark
        ? const Color(0x991C1C1E)
        : const Color(0xB2FFFFFF);
    final ink = isDark ? draftInkDark : draftInk;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final items = <Widget>[
      _menuItem(context, _Action.edit, Icons.edit_outlined, 'Edit', ink),
      if (!isWishlist) ...[
        _divider(isDark),
        _menuItem(
          context,
          _Action.favorite,
          book.isFavorite
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          book.isFavorite ? 'Remove favourite' : 'Add favourite',
          ink,
        ),
      ],
      _divider(isDark),
      _menuItem(
        context,
        _Action.move,
        isWishlist
            ? Icons.library_add_check_outlined
            : Icons.bookmark_border_rounded,
        isWishlist ? 'Move to Library' : 'Move to Wishlist',
        ink,
      ),
      if (isWishlist && onMoveUp != null) ...[
        _divider(isDark),
        _menuItem(
          context,
          _Action.up,
          Icons.arrow_upward_rounded,
          'Move up',
          ink,
        ),
      ],
      if (isWishlist && onMoveDown != null) ...[
        _divider(isDark),
        _menuItem(
          context,
          _Action.down,
          Icons.arrow_downward_rounded,
          'Move down',
          ink,
        ),
      ],
      _divider(isDark),
      _menuItem(
        context,
        _Action.delete,
        Icons.delete_outline_rounded,
        'Delete',
        draftRed,
      ),
    ];

    final menuWidth = 220.0;

    final numActions = items.where((w) => w is InkWell).length;
    final numDividers = items.where((w) => w is Container).length;
    final menuHeight = (numActions * 44.0) + (numDividers * 0.5);

    var top = position.dy;
    if (top + menuHeight > screenHeight - 24) {
      top = screenHeight - menuHeight - 24;
    }
    var left = position.dx;
    if (left + menuWidth > screenWidth - 16) {
      left = screenWidth - menuWidth - 16;
    }

    final result = await showModernContextMenu<_Action>(
      context: context,
      position: position,
      menuWidth: menuWidth,
      menuHeight: menuHeight,
      glassColor: glassColor,
      borderColor: isDark ? draftBorderDark : draftBorder,
      child: Column(mainAxisSize: MainAxisSize.min, children: items),
    );

    if (result == null) return;
    switch (result) {
      case _Action.edit:
        onEdit?.call();
      case _Action.favorite:
        onFavoriteToggle?.call();
      case _Action.move:
        onMove?.call();
      case _Action.up:
        onMoveUp?.call();
      case _Action.down:
        onMoveDown?.call();
      case _Action.delete:
        HapticFeedback.heavyImpact();
        onDelete?.call();
    }
  }

  Widget _divider(bool isDark) =>
      Container(height: 0.5, color: isDark ? draftDividerDark : draftDivider);

  Widget _menuItem(
    BuildContext context,
    _Action action,
    IconData icon,
    String label,
    Color color,
  ) {
    return InkWell(
      onTap: () => Navigator.pop(context, action),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: clashDisplayBody.copyWith(color: color, letterSpacing: 0),
            ),
            Icon(icon, size: 20, color: color),
          ],
        ),
      ),
    );
  }
}

enum _Action { edit, favorite, move, up, down, delete }

class _Cover extends ConsumerWidget {
  final Book book;
  const _Cover({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsDir = ref.watch(docsDirProvider);
    final stored = book.coverThumbPath;

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
    Color color;
    if (book.dominantColor != null && book.dominantColor!.isNotEmpty) {
      color = hexToColor(book.dominantColor!) ?? Colors.grey;
    } else {
      final hue = (book.initials.codeUnits.fold(0, (a, b) => a + b) * 47) % 360;
      color = HSLColor.fromAHSL(1, hue.toDouble(), 0.35, 0.40).toColor();
    }

    return AspectRatio(
      aspectRatio: 2 / 3,
      child: Container(
        color: color,
        alignment: Alignment.center,
        child: Text(
          book.initials,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
