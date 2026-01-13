import 'package:flutter/material.dart';

class CustomGestureDetector extends StatelessWidget {
  static const int axisX = 0;
  static const int axisY = 1;
  static const int axisBoth = 2;

  final int axis;
  final Widget child;
  final double velocityThreshold;

  // Use VoidCallback for functions with no arguments
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;

  const CustomGestureDetector({
    super.key,
    required this.child,
    required this.axis,
    this.velocityThreshold = 100.0, // Default threshold
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onSwipeUp,
    this.onSwipeDown,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior
          .translucent, // Ensures it catches swipes on empty space
      onPanEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond;

        // Vertical Logic
        if (axis == axisY || axis == axisBoth) {
          if (velocity.dy > velocityThreshold) {
            onSwipeDown?.call();
          } else if (velocity.dy < -velocityThreshold) {
            onSwipeUp?.call();
          }
        }

        // Horizontal Logic
        if (axis == axisX || axis == axisBoth) {
          if (velocity.dx > velocityThreshold) {
            onSwipeRight?.call();
          } else if (velocity.dx < -velocityThreshold) {
            onSwipeLeft?.call();
          }
        }
      },
      child: child,
    );
  }
}
