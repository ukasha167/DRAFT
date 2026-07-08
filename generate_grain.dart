import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  final random = Random();
  final width = 512;
  final height = 512;

  // grain_light: black pixels on transparent
  final imgLight = img.Image(width: width, height: height, format: img.Format.uint8, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final a = random.nextInt(256);
      imgLight.setPixelRgba(x, y, 0, 0, 0, a);
    }
  }
  File('assets/textures/grain_light.png').writeAsBytesSync(img.encodePng(imgLight));

  // grain_dark: white pixels on transparent
  final imgDark = img.Image(width: width, height: height, format: img.Format.uint8, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final a = random.nextInt(256);
      imgDark.setPixelRgba(x, y, 255, 255, 255, a);
    }
  }
  File('assets/textures/grain_dark.png').writeAsBytesSync(img.encodePng(imgDark));
  print("Grain textures generated.");
}
