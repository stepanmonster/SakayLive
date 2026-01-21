import 'package:flutter/material.dart';

/// Utility class for showing consistent toast/snackbar messages.
class ToastHelper {
  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final colors = {
      ToastType.success: const Color(0xFF4CAF50),
      ToastType.error: const Color(0xFFE53935),
      ToastType.warning: const Color(0xFFFFA726),
      ToastType.info: const Color(0xFF3B82F6),
    };

    final icons = {
      ToastType.success: Icons.check_circle,
      ToastType.error: Icons.error,
      ToastType.warning: Icons.warning,
      ToastType.info: Icons.info,
    };

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icons[type], color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: colors[type],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }

  static void success(BuildContext context, String message) {
    show(context, message, type: ToastType.success);
  }

  static void error(BuildContext context, String message) {
    show(context, message, type: ToastType.error);
  }

  static void warning(BuildContext context, String message) {
    show(context, message, type: ToastType.warning);
  }

  static void info(BuildContext context, String message) {
    show(context, message, type: ToastType.info);
  }
}

enum ToastType { success, error, warning, info }
