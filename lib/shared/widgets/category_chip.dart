import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/category.dart';

/// Small read-only chip for displaying a category label.
/// Used in list rows and the detail screen.
class CategoryChip extends StatelessWidget {
  final Category category;
  final VoidCallback? onRemove; // non-null = shows × for the Edit form

  const CategoryChip({super.key, required this.category, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppColors.accent.withOpacity(isDark ? 0.18 : 0.10);

    if (onRemove != null) {
      return Chip(
        label: Text(category.name),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: onRemove,
        backgroundColor: bg,
        labelStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.accent,
        ),
        deleteIconColor: AppColors.accent,
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
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.accent,
        ),
      ),
    );
  }
}
