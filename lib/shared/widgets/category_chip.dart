import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../domain/models/category.dart';

class CategoryChip extends StatelessWidget {
  final Category category;
  final VoidCallback? onRemove;

  const CategoryChip({super.key, required this.category, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? draftInkDark : draftInk;
    final bg = ink.withOpacity(isDark ? 0.18 : 0.10);

    if (onRemove != null) {
      return Chip(
        label: Text(category.name),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: onRemove,
        backgroundColor: bg,
        labelStyle: clashDisplayCaption.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
        deleteIconColor: ink,
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        category.name,
        style: clashDisplayCaption.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
