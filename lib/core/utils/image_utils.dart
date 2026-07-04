import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'uuid_helper.dart';

/// Holds the local paths of both generated cover sizes.
class CoverPaths {
  final String thumbPath;
  final String fullPath;
  const CoverPaths({required this.thumbPath, required this.fullPath});
}

/// Payload passed to the isolate — compute() only supports top-level args.
class _ProcessPayload {
  final Uint8List bytes;
  final int thumbWidth;
  final int fullMaxWidth;
  const _ProcessPayload(this.bytes, this.thumbWidth, this.fullMaxWidth);
}

/// Return value from the isolate.
class _ProcessResult {
  final Uint8List thumbBytes;
  final Uint8List fullBytes;
  const _ProcessResult(this.thumbBytes, this.fullBytes);
}

/// Top-level function — required by compute().
/// Runs in a separate isolate so the main thread is never blocked.
_ProcessResult _processInIsolate(_ProcessPayload payload) {
  final original = img.decodeImage(payload.bytes);
  if (original == null) throw const FormatException('Cannot decode image');

  // Thumbnail: fixed width, aspect-ratio height.
  final thumbH =
      (payload.thumbWidth * original.height / original.width).round();
  final thumb = img.copyResize(
    original,
    width: payload.thumbWidth,
    height: thumbH,
    interpolation: img.Interpolation.linear,
  );

  // Full: cap width if oversized, preserve aspect ratio.
  final full = original.width > payload.fullMaxWidth
      ? img.copyResize(original, width: payload.fullMaxWidth,
          interpolation: img.Interpolation.linear)
      : original;

  return _ProcessResult(
    Uint8List.fromList(img.encodeJpg(thumb, quality: 85)),
    Uint8List.fromList(img.encodeJpg(full, quality: 90)),
  );
}

/// Download a remote cover URL, resize it off-thread, write both sizes to
/// disk, and return their local paths. Returns null if the download fails.
Future<CoverPaths?> downloadAndProcessCover(String url) async {
  try {
    // Use HttpClient instead of dio to keep isolate-safe.
    final request = await HttpClient().getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) return null;

    final bytes = await consolidateHttpClientResponseBytes(response);
    return processAndSaveCover(bytes);
  } catch (_) {
    return null;
  }
}

/// Process raw image bytes, save both sizes, and return RELATIVE paths
/// from the application documents directory.
///
/// Relative paths are stable across clean builds and reinstalls.
/// Absolute paths from getApplicationDocumentsDirectory() are NOT — iOS
/// reassigns the container UUID on every clean install/rebuild from Xcode.
Future<CoverPaths?> processAndSaveCover(Uint8List bytes) async {
  try {
    final result = await compute(
      _processInIsolate,
      _ProcessPayload(bytes, 150, 800),
    );

    final dir = await getApplicationDocumentsDirectory();
    final coversDir = Directory(p.join(dir.path, 'covers'));
    await coversDir.create(recursive: true);

    final baseName = newId();
    final thumbRel = p.join('covers', '${baseName}_thumb.jpg');
    final fullRel = p.join('covers', '${baseName}_full.jpg');

    await File(p.join(dir.path, thumbRel)).writeAsBytes(result.thumbBytes);
    await File(p.join(dir.path, fullRel)).writeAsBytes(result.fullBytes);

    return CoverPaths(thumbPath: thumbRel, fullPath: fullRel);
  } catch (_) {
    return null;
  }
}

/// Delete cover files by their stored paths (relative or absolute).
/// Handles both formats so old absolute-path records degrade gracefully
/// rather than crashing.
Future<void> deleteCoverFiles(String? thumbPath, String? fullPath) async {
  final dir = await getApplicationDocumentsDirectory();
  for (final stored in [thumbPath, fullPath]) {
    if (stored == null) continue;
    // Reconstruct: relative paths need the docs prefix; old absolute paths used as-is.
    final file =
        File(p.isAbsolute(stored) ? stored : p.join(dir.path, stored));
    if (await file.exists()) await file.delete();
  }
}
