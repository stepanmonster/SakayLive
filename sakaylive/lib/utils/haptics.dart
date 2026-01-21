import 'package:flutter/services.dart';

/// Utility class for haptic feedback throughout the app.
/// Provides consistent tactile responses for user interactions.
class Haptics {
  /// Light tap - for button presses
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// Medium tap - for selections
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy tap - for important actions
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  /// Selection changed - for toggles, pickers
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// Success - for completed actions
  static void success() {
    HapticFeedback.mediumImpact();
  }

  /// Error/Warning
  static void error() {
    HapticFeedback.heavyImpact();
  }
}
