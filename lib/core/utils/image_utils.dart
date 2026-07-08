import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;
import 'package:palette_generator/palette_generator.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'uuid_helper.dart';

class CoverPaths {
  final String thumbPath;
  final String fullPath;
  final String? dominantColor;
  const CoverPaths({
    required this.thumbPath,
    required this.fullPath,
    this.dominantColor,
  });
}

class _ProcessPayload {
  final Uint8List bytes;
  final int thumbWidth;
  final int fullMaxWidth;
  const _ProcessPayload(this.bytes, this.thumbWidth, this.fullMaxWidth);
}

class _ProcessResult {
  final Uint8List thumbBytes;
  final Uint8List fullBytes;
  const _ProcessResult(this.thumbBytes, this.fullBytes);
}

_ProcessResult _processInIsolate(_ProcessPayload payload) {
  final original = img.decodeImage(payload.bytes);
  if (original == null) throw const FormatException('Cannot decode image');

  final thumbH = (payload.thumbWidth * original.height / original.width)
      .round();
  final thumb = img.copyResize(
    original,
    width: payload.thumbWidth,
    height: thumbH,
    interpolation: img.Interpolation.linear,
  );

  final full = original.width > payload.fullMaxWidth
      ? img.copyResize(
          original,
          width: payload.fullMaxWidth,
          interpolation: img.Interpolation.linear,
        )
      : original;

  return _ProcessResult(
    Uint8List.fromList(img.encodeJpg(thumb, quality: 85)),
    Uint8List.fromList(img.encodeJpg(full, quality: 90)),
  );
}

Future<CoverPaths?> downloadAndProcessCover(String url) async {
  try {
    final request = await HttpClient().getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) return null;

    final bytes = await consolidateHttpClientResponseBytes(response);
    return processAndSaveCover(bytes);
  } catch (_) {
    return null;
  }
}

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

    String? dominantColorHex;
    try {
      final imageProvider = MemoryImage(result.thumbBytes);
      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 5,
      );
      final color = palette.dominantColor?.color;
      if (color != null) {
        dominantColorHex =
            '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      }
    } catch (_) {}

    return CoverPaths(
      thumbPath: thumbRel,
      fullPath: fullRel,
      dominantColor: dominantColorHex,
    );
  } catch (_) {
    return null;
  }
}

Future<void> deleteCoverFiles(String? thumbPath, String? fullPath) async {
  final dir = await getApplicationDocumentsDirectory();
  for (final stored in [thumbPath, fullPath]) {
    if (stored == null) continue;

    final file = File(p.isAbsolute(stored) ? stored : p.join(dir.path, stored));
    if (await file.exists()) await file.delete();
  }
}

Future<CoverPaths?> processLocalFileCover(String filePath) async {
  try {
    final bytes = await File(filePath).readAsBytes();
    return processAndSaveCover(bytes);
  } catch (_) {
    return null;
  }
}
