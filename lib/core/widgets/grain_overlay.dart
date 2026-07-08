import 'package:flutter/material.dart';

class GrainOverlay extends StatelessWidget {
  final Widget child;

  const GrainOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: isDarkMode ? 0.025 : 0.035,
              child: Image.asset(
                isDarkMode
                    ? 'assets/textures/grain_dark.png'
                    : 'assets/textures/grain_light.png',
                repeat: ImageRepeat.repeat,
                fit: BoxFit.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
