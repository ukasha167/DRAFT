import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../data/providers/repository_providers.dart';

/// Renders a book cover at the correct 2:3 aspect ratio.
///
/// Paths stored in the DB are RELATIVE to the documents directory
/// (e.g. "covers/abc_thumb.jpg"). This widget reconstructs the absolute
/// path at display time using [docsDirProvider], which is stable across
/// the widget lifecycle even when iOS reassigns container UUIDs.
///
/// Old absolute-path records (written before this fix) are detected via
/// [p.isAbsolute] and used as-is — they will fail existsSync and fall
/// through to the placeholder, degrading gracefully without crashing.
///
/// Uses cacheWidth/cacheHeight on Image.file so Flutter decodes at display
/// size only — never full-resolution for a list thumbnail.
class BookCover extends ConsumerWidget {
  final String? thumbPath; // relative path, or legacy absolute
  final String? fullPath;
  final String initials;
  final double width;

  /// True only on the detail screen — loads fullPath at full display size.
  final bool useFullRes;

  const BookCover({
    super.key,
    this.thumbPath,
    this.fullPath,
    required this.initials,
    required this.width,
    this.useFullRes = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final height = width * 1.5; // 2:3 ratio
    final storedPath = useFullRes ? fullPath : thumbPath;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    if (storedPath != null) {
      final docsDir = ref.watch(docsDirProvider);

      // Relative paths (new format) need the docs prefix.
      // Absolute paths (old format written before the fix) used as-is;
      // they will likely fail existsSync after a clean build, which is
      // fine — the widget falls through to the placeholder without crashing.
      final resolved =
          p.isAbsolute(storedPath) ? storedPath : p.join(docsDir, storedPath);

      if (File(resolved).existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(
            File(resolved),
            width: width,
            height: height,
            fit: BoxFit.cover,
            cacheWidth: (width * dpr).ceil(),
            cacheHeight: (height * dpr).ceil(),
            errorBuilder: (_, __, ___) => _Placeholder(
              width: width,
              height: height,
              initials: initials,
            ),
          ),
        );
      }
    }

    return _Placeholder(width: width, height: height, initials: initials);
  }
}

class _Placeholder extends StatelessWidget {
  final double width;
  final double height;
  final String initials;

  const _Placeholder({
    required this.width,
    required this.height,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final hue = (initials.codeUnits.fold(0, (a, b) => a + b) * 47) % 360;
    final color = HSLColor.fromAHSL(1, hue.toDouble(), 0.4, 0.45).toColor();
    final fontSize = math.min(width * 0.4, 22.0);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
