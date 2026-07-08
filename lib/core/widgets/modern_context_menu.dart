import 'dart:ui';
import 'package:flutter/material.dart';

class ModernContextMenuRoute<T> extends PopupRoute<T> {
  final Widget child;
  final Offset position;
  final double menuWidth;
  final double menuHeight;
  final Color glassColor;
  final Color borderColor;
  final Alignment originAlignment;

  ModernContextMenuRoute({
    required this.child,
    required this.position,
    required this.menuWidth,
    required this.menuHeight,
    required this.glassColor,
    required this.borderColor,
    required this.originAlignment,
  });

  @override
  Color? get barrierColor => Colors.black.withOpacity(0.02);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Menu';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 100);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return child;
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    var top = position.dy;
    if (top + menuHeight > screenHeight - 24) {
      top = screenHeight - menuHeight - 24;
    }
    var left = position.dx;
    if (left + menuWidth > screenWidth - 16) {
      left = screenWidth - menuWidth - 16;
    }

    // Dynamic scale origin (if caller did not specify an exact one, calculate it)
    Alignment finalAlignment = originAlignment;
    if (originAlignment == Alignment.center) {
      final originX = ((position.dx - left) / menuWidth) * 2 - 1;
      final originY = ((position.dy - top) / menuHeight) * 2 - 1;
      finalAlignment = Alignment(originX.clamp(-1.0, 1.0), originY.clamp(-1.0, 1.0));
    }

    // Custom cubic curve simulating Apple's tight spring feel: 0.16, 1, 0.3, 1
    final curve = CurvedAnimation(parent: animation, curve: const Cubic(0.16, 1, 0.3, 1));
    
    // Smoothly scale from 0.85 to 1.0 based on native interaction specs
    final scale = Tween<double>(begin: 0.85, end: 1.0).animate(curve);

    return Stack(
      children: [
        Positioned(
          top: top,
          left: left,
          child: FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              scale: scale,
              alignment: finalAlignment,
              child: Material(
                color: Colors.transparent,
                elevation: 20,
                shadowColor: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      width: menuWidth,
                      decoration: BoxDecoration(
                        color: glassColor,
                        border: Border.all(color: borderColor, width: 0.5),
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<T?> showModernContextMenu<T>({
  required BuildContext context,
  required Offset position,
  required Widget child,
  required double menuWidth,
  required double menuHeight,
  required Color glassColor,
  required Color borderColor,
  Alignment originAlignment = Alignment.center,
}) {
  return Navigator.of(context).push(ModernContextMenuRoute<T>(
    child: child,
    position: position,
    menuWidth: menuWidth,
    menuHeight: menuHeight,
    glassColor: glassColor,
    borderColor: borderColor,
    originAlignment: originAlignment,
  ));
}
