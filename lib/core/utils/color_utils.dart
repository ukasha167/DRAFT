import 'package:flutter/material.dart';

Color? hexToColor(String? hexString) {
  if (hexString == null || hexString.isEmpty) return null;
  final buffer = StringBuffer();
  if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
  buffer.write(hexString.replaceFirst('#', ''));
  final intValue = int.tryParse(buffer.toString(), radix: 16);
  if (intValue == null) return null;
  return Color(intValue);
}

Color? getWashedAmbientColor(String? hexString, bool isDark) {
  final dom = hexToColor(hexString);
  if (dom == null) return null;
  final hsl = HSLColor.fromColor(dom);
  return hsl.withLightness(isDark ? 0.15 : 0.94).withSaturation(isDark ? 0.3 : 0.4).toColor();
}
